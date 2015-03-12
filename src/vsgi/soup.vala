using Soup;

/**
 * Soup implementation of VSGI.
 */
namespace VSGI {

	/**
	 * Soup Request
	 */
	class SoupRequest : VSGI.Request {

		private Soup.Message message;
		private HashTable<string, string>? _query;

		public override HTTPVersion http_version {
			get {
				return this.message.http_version;
			}
		}

		public override string method { owned get { return this.message.method ; } }

		public override URI uri { get { return this.message.uri; } }

		public override HashTable<string, string>? query { get { return this._query; } }

		public SoupRequest(Soup.Message msg, HashTable<string, string>? query) {
			Object (headers: msg.request_headers);
			this.message = msg;
			this._query = query;
		}

		/**
		 * Offset from which the response body is being read.
		 */
		private int64 offset = 0;

		public override ssize_t read (uint8[] buffer, Cancellable? cancellable = null) {
			var chunk = this.message.request_body.get_chunk (offset);

			/* potentially more data... */
			if (chunk == null)
				return -1;

			// copy the data into the buffer
			Memory.copy (buffer, chunk.data, chunk.length);

			offset += chunk.length;

			return (ssize_t) chunk.length;
		}

		/**
		 * This will complete the request MessageBody.
		 */
		public override bool close (Cancellable? cancellable = null) {
			this.message.request_body.complete ();
			return true;
		}
	}

	/**
	 * Soup Response
	 */
	class SoupResponse : VSGI.Response {

		private Soup.Message message;

		public override uint status {
			get { return this.message.status_code; }
			set { this.message.set_status (value); }
		}

		public SoupResponse (SoupRequest req, Soup.Message msg) {
			Object (request: req, headers: msg.response_headers);
			this.message = msg;
		}

		public override ssize_t write (uint8[] buffer, Cancellable? cancellable = null) {
			this.message.response_body.append_take (buffer);
			return buffer.length;
		}

		/**
		 * Status line is automatically written by the inner {@link Soup.Message}.
		 */
		public override ssize_t write_status_line (Cancellable? cancellable = null) {
			return 0;
		}

		/**
		 * Headers are automatically written by the inner {@link Soup.Message}.
		 */
		public override ssize_t write_headers (Cancellable? cancellable = null) {
			return 0;
		}

		/**
		 * This will complete the response MessageBody.
         *
		 * Once called, you will not be able to alter the stream.
		 */
		public override bool close (Cancellable? cancellable = null) {
			this.message.response_body.complete ();
			return true;
		}
	}

	/**
	 * Implementation of VSGI.Server based on Soup.Server.
	 *
	 * @since 0.1
	 */
	public class SoupServer : VSGI.Server {

		private Soup.Server server;

		public SoupServer (VSGI.Application app, uint port) throws Error {
			base (app);
			this.server = new Soup.Server (Soup.SERVER_PORT, 3003);
		}

		/**
		 * Creates a Soup.Server, bind the application to it using a closure and
		 * start the server.
		 */
		public override int run (string[]? args = null) {

			Soup.ServerCallback soup_handler = (server, msg, path, query, client) => {

				var req = new SoupRequest (msg, query);
				var res = new SoupResponse (req, msg);

				this.application.handle (req, res);

				message ("%u %s %s".printf (res.status, req.method, req.uri.get_path ()));
			};

			this.server.add_handler (null, soup_handler);

			message ("listening on http://%s:%u", server.interface.physical, server.interface.port);

			// run the server
			this.server.run ();

			return 0;
		}
	}
}
