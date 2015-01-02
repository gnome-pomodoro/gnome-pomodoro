public abstract class Pomodoro.Module : GLib.Object
{
    ~Module ()
    {
        this.disable ();
    }

    public void enable ()
    {
    }

    public void disable ()
    {
    }
}
