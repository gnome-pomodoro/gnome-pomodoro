namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/accelerator-row.ui")]
    public class AcceleratorRow : Adw.ActionRow
    {
        [CCode (notify = false)]
        public string accelerator {
            get {
                return this._accelerator;
            }
            construct set {
                if (value == null) {
                    value = "";
                }

                if (this._accelerator != value) {
                    this._accelerator = value;
                    this.notify_property ("accelerator");
                }

                this.update_label ();
            }
        }

        public string description { get; set; }

        [GtkChild]
        private unowned Gtk.Label accelerator_label;

        private string _accelerator;

        construct
        {
            this.accelerator_label.set_direction (Gtk.TextDirection.LTR);
        }

        private void update_label ()
        {
            var accelerator = this._accelerator != ""
                ? Pomodoro.Accelerator.from_string (this._accelerator)
                : Pomodoro.Accelerator.empty ();

            if (accelerator.is_empty ()) {
                this.accelerator_label.label = _("Disabled");
                this.accelerator_label.add_css_class ("dim-label");
            }
            else {
                this.accelerator_label.label = accelerator.get_label ();
                this.accelerator_label.remove_css_class ("dim-label");
            }
        }

        private Pomodoro.AcceleratorChooserWindow create_accelerator_chooser ()
        {
            var chooser = new Pomodoro.AcceleratorChooserWindow (this.description, this.accelerator);
            chooser.transient_for = (Gtk.Window) this.get_root ();

            return chooser;
        }

        private void on_chooser_response (Pomodoro.AcceleratorChooserWindow chooser,
                                          int                               response_id)
        {
            if (response_id != Gtk.ResponseType.APPLY) {
                return;
            }

            this.accelerator = chooser.accelerator;
        }

        [GtkCallback]
        public void on_activated ()
        {
            var chooser = this.create_accelerator_chooser ();
            chooser.response.connect (this.on_chooser_response);
            chooser.present ();
        }
    }
}
