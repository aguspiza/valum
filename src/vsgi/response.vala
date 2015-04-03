namespace VSGI {

	/**
	 * Response
	 *
	 * @since 0.0.1
	 */
	public abstract class Response : OutputStream {

		/**
		 * @since 0.1
		 */
		public Request request { construct; get; }

		/**
		 * Tells if the status line has been written.
		 *
		 * Once set to true, call to {@link write_status_line} must fail.
		 *
		 * @since 0.1
		 */
		public bool status_line_written { get; protected set; default = false; }

		/**
		 * Tells if the response headers have been written.
		 *
		 * Once set to true, call to {@link write_headers} must fail.
		 *
		 * @since 0.1
		 */
		public bool headers_written { get; protected set; default = false; }

		/**
		 * Response status.
		 *
		 * @since 0.0.1
		 */
		public abstract uint status { get; set; }

		/**
		 * Response headers.
		 *
		 * @since 0.0.1
		 */
		public Soup.MessageHeaders headers { construct; get; }

		/**
		 * Property for the Set-Cookie header.
		 *
		 * @since 0.1
		 */
		public virtual SList<Soup.Cookie> cookies {
			set {
				this.headers.remove ("Set-Cookie");

				foreach (var cookie in value) {
					this.headers.append ("Set-Cookie", cookie.to_set_cookie_header ());
				}
			}
		}

		/**
		 * Write the status line in the {@link Response}.
		 *
		 * @since 0.1
		 */
		public virtual ssize_t write_status_line (Cancellable? cancellable) throws GLib.IOError {
			if (status_line_written)
				error ("status line already written");

			var written = this.write ("%u %s".printf (this.status, Soup.Status.get_phrase (this.status)).data);

			this.status_line_written = true;

			return written;
		}

		/**
		 * Write the headers and a new line in the {@link Response}.
		 *
		 * This must be called in order to perform any {@link write} operations,
		 * otherwise the response will be corrupted.
		 *
		 * @since 0.1
		 */
		public virtual ssize_t write_headers (Cancellable? cancellable = null) throws GLib.IOError {
			if (this.headers_written)
				error ("headers already written");

			ssize_t written = 0;

			if (!this.status_line_written)
				written += write_status_line (cancellable);

			// headers
			this.headers.foreach ((k, v) => {
				written += this.write ("%s: %s\r\n".printf(k, v).data, cancellable);
			});

			// newline preceeding the body
			written += this.write ("\r\n".data, cancellable);

			this.headers_written = true;

			return written;
		}
	}
}
