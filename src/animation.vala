/*
 * Copyright (c) 2013 gnome-shell-pomodoro contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;

public delegate double Pomodoro.AnimationFunc (double progress);

public enum Pomodoro.AnimationMode
{
    LINEAR,
    EASE_IN,
    EASE_OUT,
    EASE_IN_CUBIC,
    EASE_OUT_CUBIC,
    EASE_IN_OUT
}

private double calculate_linear (double t)
{
    return t;
}

//private double calculate_bezier (double t, double b, double c)
//{
////    Px = (1-t)^3(P1x) + 3t(1-t)^2(P2x) + 3t^2(1-t)(P3x) + t^3(P4x)
//    return (3 * (1.0 - t) * ((1.0 - t)*b + t*c) + t * t) * t;
//}

//private double calculate_ease_in (double t)
//{
//    return calculate_bezier (double t, );
//}

//private double calculate_ease_out (double t)
//{
//    return 1.0 - calculate_bezier (1.0 - t, );
//}

private double calculate_ease_in (double t)
{
    return t * t;
}

private double calculate_ease_out (double t)
{
    return (2.0 - t) * t;
}

private double calculate_ease_in_cubic (double t)
{
    return t * t * t;
}

private double calculate_ease_out_cubic (double t)
{
    return ((t - 3.0) * t + 3.0) * t;
}

private double calculate_ease_in_out (double t)
{
    return ((1.0 - t) + (2.0 - t)) * (t * t);
    // return (1.0 - t) * calculate_ease_in(t)
    //             + t * calculate_ease_out(t);
}

//private double calculate_ease_in_power (double t, double power)
//{
//    return Math.pow (t, power);
//}

//private double calculate_ease_out_power (double t, double power)
//{
//    return 1.0 - Math.pow (1.0 - t, power);
//}

public class Pomodoro.Animation : Object
{
    public uint duration;
    public uint interval;
    public double value_from = 0.0;
    public double value_to = 1.0;

    public double progress = 0.0;
    public double value = 0.0;

    private uint64 timestamp;
    private uint timeout_id;
    private AnimationFunc func;


    public Animation (uint duration, AnimationMode mode)
    {
        this.duration = duration;
        this.interval = 20;  // 50 fps

        this.progress = 0.0;
        this.timeout_id = 0;

        switch (mode)
        {
            case AnimationMode.LINEAR:
                this.func = calculate_linear;
                break;

            case AnimationMode.EASE_IN:
                this.func = calculate_ease_in;
                break;

            case AnimationMode.EASE_OUT:
                this.func = calculate_ease_out;
                break;

            case AnimationMode.EASE_IN_CUBIC:
                this.func = calculate_ease_in_cubic;
                break;

            case AnimationMode.EASE_OUT_CUBIC:
                this.func = calculate_ease_out_cubic;
                break;

            case AnimationMode.EASE_IN_OUT:
                this.func = calculate_ease_in_out;
                break;

            default:
                this.func = calculate_linear;
                break;
        }
    }

    ~Animation ()
    {
        this.stop ();
    }

    public double compute_value (double progress)
    {
        var easing = func (progress.clamp (0.0, 1.0));
        return this.value_from + easing * (this.value_to - this.value_from);    
    }

    private bool on_timeout ()
    {
        var timestamp = GLib.get_real_time() / 1000;

        if (this.duration > 0)
            this.progress = ((double)(timestamp - this.timestamp)
                        / (double) this.duration).clamp (0.0, 1.0);
        else
            this.progress = 1.0;

        this.value = this.compute_value (this.progress);

        this.value_changed (this.value);
        // this.func (this); // TODO: use function instead of signal

        if (this.progress == 1.0)
        {
            this.stop ();
            this.completed ();

            return false;
        }

        return true;
    }

    public void animate_to (double value_to)
    {
        this.value_from = this.value;
        this.value_to = value_to;

        this.progress = 0.0;
        this.timestamp = GLib.get_real_time() / 1000;

        if (this.timeout_id == 0)
        {
            if (this.duration > 0)
                this.timeout_id = GLib.Timeout.add (
                        uint.min(this.interval, this.duration),
                        (GLib.SourceFunc) this.on_timeout);

            this.started ();
        }

        this.on_timeout (); // TODO rename to update and make public?

    }

    public void stop ()
    {
        if (this.timeout_id != 0) {
            GLib.Source.remove (this.timeout_id);
            this.timeout_id = 0;
        }
    }

    public virtual signal void destroy ()
    {
        this.stop();
    }

    public signal void started ();
    public signal void value_changed (double value);
    public signal void completed ();
}

