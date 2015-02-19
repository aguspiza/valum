using VSGI;

namespace Valum {

	/**
	 * Built-in middlewares.
	 *
	 * Middleware are functions respecting the {@link RouteCallback} signature
	 * that provides composable features.
	 */
	namespace Middleware {

		/**
		 * Serve static files from a given root.
		 *
		 * The {@link Request} must define the following parameters:
		 *
		 *  * path: relative path to the root where the resource is located
		 *
		 * @param root path from which resources are loaded
		 */
		public static Route.Handler serve_files (GLib.File root) {

			assert (root != null);
			assert (root.query_exists ());
			assert (root.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY);

			return (req, res) => {
				var writer   = new DataOutputStream (res);
				var path     = req.params["path"];
				var contents = new uint8[128];
				bool uncertain;

				assert (path != null);

				try {
					var file = root.resolve_relative_path (path);

					// read 128 bytes for the content-type guess
					file.read ().read (contents);
					res.headers.set_content_type (ContentType.guess(path, contents, out uncertain), null);

					if (uncertain)
						warning ("could not infer content type of file %s with certainty".printf (path));

					// transfer the file
					res.splice (file.read (), OutputStreamSpliceFlags.CLOSE_SOURCE);
				} catch (FileError fe) {
					throw new ClientError.NOT_FOUND (fe.message);
				}
			};
		}

		/**
		 * Serve gresource from a resource bundle.
		 *
		 * @param resource resource bundle to serve
		 * @param prefix   prefix from which resources are resolved
		 */
		public static Route.Handler serve_resources (GLib.Resource resource, string prefix = "/") {
			return (req, res) => {
				var path = req.params["path"];

				assert (path != null);

				path = Path.build_filename (prefix, path);

			};
		}

		/**
		 * Serve global resources from a given prefix.
		 *
		 * @see resources_open_stream
		 * @see resources_lookup_data
		 *
		 * @param prefix prefix from which resources are resolved
		 */
		public static Route.Handler serve_global_resources (string prefix = "/") {
			return (req, res) => {
				var path = req.params["path"];

				assert (path != null);

				path = Path.build_filename (prefix, path);

				try {
					var input = resources_open_stream (path, ResourceLookupFlags.NONE);
					var contents = resources_lookup_data (path, ResourceLookupFlags.NONE).get_data ();
					bool uncertain;

					// guess the content-type
					res.headers.set_content_type (ContentType.guess (path, contents, out uncertain), null);

					res.splice (input, OutputStreamSpliceFlags.CLOSE_SOURCE);
				} catch (IOError e) {
					throw new ClientError.NOT_FOUND (e.message);
				}
			};
		}
	}
}
