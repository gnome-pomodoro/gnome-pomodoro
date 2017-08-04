/*
 * Copyright (c) 2017 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

using GLib;


namespace Pomodoro
{
    private class StatsMonthPage : StatsPage
    {
        public StatsMonthPage (Gom.Repository repository,
                               GLib.DateTime  date)
        {
            GLib.Object (date: date);

            this.repository = repository;

            this.update ();
        }

        protected override string format_datetime (GLib.DateTime date)
        {
            return date.format ("%B %Y");
        }

        public override GLib.DateTime get_previous_date ()
        {
            return this.date.add_months (-1);
        }

        public override GLib.DateTime get_next_date ()
        {
            return this.date.add_months (1);
        }

        public override async uint64 get_reference_value ()
        {
            return yield AggregatedEntry.get_baseline_monthly_elapsed ();
        }
   }
}
