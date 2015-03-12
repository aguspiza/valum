namespace VSGI {

	/**
	 * Server serving a single {@link Application}.
	 *
	 * Provides abstraction over concrete server and protocol implementations.
	 *
	 * @since 0.1
	 */
	public abstract class Server : Object {

		/**
		 * Application handling incoming request.
		 */
		protected VSGI.Application application;

		/**
		 * Creates a new Server that serve a given application.
		 *
		 * @since 0.1
		 *
		 * @param app application served by this server.
		 */
		public Server (VSGI.Application app) {
			this.application = app;
		}

		/**
		 * Start listening on incoming requests.
		 *
		 * @since 0.1
		 */
		public abstract int run (string[]? args = null);
	}
}
