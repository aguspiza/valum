using FastCGI;

/**
 * FastCGI implementation of VSGI.
 */
namespace VSGI {

	/**
	 * FastCGI Request parsed from FastCGI.request struct.
	 */
	class FastCGIRequest : Request {

		private new weak FastCGI.request request;

		private string _method = Request.GET;
		private Soup.URI _uri;
		private HashTable<string, string>? _query = null;

		public override Soup.URI uri { get { return this._uri; } }

		public override HashTable<string, string>? query {
			get {
				return this._query;
			}
		}

		public override Soup.HTTPVersion http_version {
			get {
				if (request.environment["HTTP_VERSION"] == null) {
					warning ("could not infer the HTTP protocol, fallback to HTTP/1.1");
					return Soup.HTTPVersion.@1_1;
				}

				switch (request.environment["HTTP_VERSION"]) {
					case "HTTP/1.0":
						return Soup.HTTPVersion.@1_0;
					default:
					case "HTTP/1.1":
						return Soup.HTTPVersion.@1_1;
				}
			}
		}

		public override string method {
			owned get { return this._method; }
		}

		public FastCGIRequest(FastCGI.request request) {
			Object (headers: new Soup.MessageHeaders (Soup.MessageHeadersType.RESPONSE));

			this.request = request;

			var environment = this.request.environment;

			this._uri = new Soup.URI (environment["PATH_TRANSLATED"]);

			// nullables
			this._uri.set_host (environment["SERVER_NAME"]);
			this._uri.set_query (environment["QUERY_STRING"]);

			// HTTP authentication credentials
			this._uri.set_user (environment["REMOTE_USER"]);

			if (environment["PATH_INFO"] != null)
				this._uri.set_path ((string) environment["PATH_INFO"]);

			// some server provide this one for the path
			if (environment["REQUEST_URI"] != null)
				this._uri.set_path ((string) environment["REQUEST_URI"]);

			if (environment["SERVER_PORT"] != null)
				this._uri.set_port (int.parse (environment["SERVER_PORT"]));

			if (environment["REQUEST_METHOD"] != null)
				this._method = (string) environment["REQUEST_METHOD"];

			// parse the HTTP query
			if (environment["QUERY_STRING"] != null)
				this._query = Soup.Form.decode ((string) environment["QUERY_STRING"]);

			foreach (var variable in this.request.environment.get_all ()) {
				// headers are prefixed with HTTP_
				if (variable.has_prefix ("HTTP_")) {
					var parts = variable.split("=", 2);
					headers.append (parts[0].substring(5).replace("_", "-").casefold(), parts[1]);
				}
			}
		}

		public override ssize_t read (uint8[] buffer, Cancellable? cancellable = null) throws IOError {
			var read = this.request.in.read (buffer);

			if (read == GLib.FileStream.EOF)
				throw new IOError.FAILED ("code %u: could not read from stream".printf (this.request.in.get_error ()));

			return read;
		}

		public bool flush (Cancellable? cancellable = null) {
			return this.request.in.flush ();
		}

		public override bool close (Cancellable? cancellable = null) throws IOError {
			return this.request.in.is_closed;
		}
	}

	/**
	 * FastCGI Response
	 */
	class FastCGIResponse : Response {

		private new weak FastCGI.request fastcgi_request;

		/**
		 * {@inheritDoc}
		 *
		 * The status is stored in the response 'Status' headers according to CGI
		 * specifications.
		 */
		public override uint status {
			get {
				Soup.HTTPVersion ver;
				uint status_code;
				string reason_phrase;
				Soup.headers_parse_status_line ("HTTP/1.1 %".printf(headers.get_one ("Status")), out ver, out status_code, out reason_phrase);
				return status_code;
			}
			set {
				headers.replace ("Status", "%u %s".printf (value, Soup.Status.get_phrase (value)));
			}
		}

		public FastCGIResponse(FastCGIRequest req, FastCGI.request request) {
			Object (request: req, headers: new Soup.MessageHeaders (Soup.MessageHeadersType.REQUEST));
			this.fastcgi_request = request;
		}

		/**
		 * Status line is included in the {@link headers}.
		 */
		public override ssize_t write_status_line (Cancellable? cancellable = null) {
			return 0;
		}

		public override ssize_t write (uint8[] buffer, Cancellable? cancellable = null) {
			ssize_t written = 0;

			if (!this.headers_written)
				written += this.write_headers (cancellable);

			written += this.fastcgi_request.out.put_str (buffer);

			if (written == GLib.FileStream.EOF)
				throw new IOError.FAILED ("code %u: could not write body to stream".printf (this.fastcgi_request.out.get_error ()));

			return written;
		}

		/**
		 * Headers are written on the first flush call.
		 */
		public override bool flush (Cancellable? cancellable = null) {
			return this.fastcgi_request.out.flush ();
		}

		public override bool close (Cancellable? cancellable = null) throws IOError {
			return this.fastcgi_request.out.is_closed;
		}
	}

	/**
	 * FastCGI Server using GLib.MainLoop.
	 *
	 * @since 0.1
	 */
	public class FastCGIServer : VSGI.Server {

		private FastCGI.request request;

		public FastCGIServer (VSGI.Application app) {
			base (app);

			FastCGI.init ();

			FastCGI.request.init (out this.request);
		}

		/**
		 * Create a FastCGI Server from a socket.
		 *
		 * @since 0.1
		 *
		 * @param path    socket path or port number (port are written like :8080)
		 * @param backlog listen queue depth
		 */
		public FastCGIServer.from_socket (VSGI.Application app, string path, int backlog) {
			base (app);

			FastCGI.init ();

			var socket = FastCGI.open_socket (path, 0);

			assert (socket != -1);

			FastCGI.request.init (out this.request, socket);
		}

		public override int run (string[]? args = null) {
			var loop = new MainLoop ();
			var source = new TimeoutSource (0);

			source.set_callback (() => {
				// accept a new request
				var status = this.request.accept ();

				if (status < 0) {
					warning ("could not accept a request (code %d)", status);
					this.request.close ();
					loop.quit ();
					return false;
				}

				foreach (var env in this.request.environment.get_all())
					message (env);

				var req = new VSGI.FastCGIRequest (this.request);
				var res = new VSGI.FastCGIResponse (req, this.request);

				try {
					this.application.handle (req, res);
				} catch (Error e) {
					this.request.err.puts (e.message);
					this.request.out.set_exit_status (e.code);
				}

				message ("%u %s %s".printf (res.status, req.method, req.uri.get_path ()));

				this.request.finish ();

				return true;
			});

			source.attach (loop.get_context ());

			loop.run ();

			return 0;
		}
	}
}
