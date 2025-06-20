using GLib;


namespace Freedesktop
{
    private uint                                        next_request_id = 1U;
    private GLib.HashTable<string, Freedesktop.Request> requests = null;


    public delegate void RequestCallback (uint32                               response,
                                          GLib.HashTable<string, GLib.Variant> results);


    public async string create_request (GLib.DBusConnection         connection,
                                        Freedesktop.RequestCallback callback) throws GLib.Error
    {
        var request_id     = next_request_id;
        var handle_token   = "gnomepomodoro_" + request_id.to_string ();
        var sender         = connection.get_unique_name ();
        var sender_escaped = sender.replace (":", "").replace (".", "_");

        next_request_id++;

        var request_proxy = yield GLib.Bus.get_proxy<Freedesktop.Request> (
                BusType.SESSION,
                "org.freedesktop.portal.Desktop",
                @"/org/freedesktop/portal/desktop/request/$(sender_escaped)/$(handle_token)");
        request_proxy.response.connect (
            (response, results) => {
                Freedesktop.destroy_request (handle_token);

                callback (response, results);
            });

        if (requests == null) {
            requests = new GLib.HashTable<string, Freedesktop.Request> (GLib.str_hash,
                                                                        GLib.str_equal);
        }

        requests.insert (handle_token, request_proxy);

        return handle_token;
    }


    public bool destroy_request (string handle_token)
    {
        return requests != null
            ? requests.remove (handle_token)
            : false;
    }
}
