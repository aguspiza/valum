/**
 * Test implementation of VSGI.Response to stub a response.
 */
public class TestResponse : VSGI.Response {

	private uint _status;

	public override uint status { get { return this._status; } set { this._status = value; } }

	public TestResponse (TestRequest req, uint status) {
		Object (request: req);
		this._status = status;
	}

	public override ssize_t write (uint8[] buffer, Cancellable? cancellable = null) {
		return 0;
	}

	public override bool close (Cancellable? cancellable = null) {
		return true;
	}
}
