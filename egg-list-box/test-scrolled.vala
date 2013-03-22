/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using Egg;

class Row : Grid {
  public int32 value;
  public Row () {
	value = Random.int_range (0, 10000);
	var l = new Label ("Value %u".printf (value));
	this.add (l);
	l.show ();
  }

	
}
public static int
compare (Widget a, Widget b) {
  return (int32)(b as Row).value - (int32)(a as Row).value;
}

public static bool
filter (Widget widget) {
  return (widget as Row).value % 2 == 0;
}

public static int
main (string[] args) {
  int num_rows = 0;

  Gtk.init (ref args);

  if (args.length > 1)
	num_rows = int.parse (args[1]);

  if (num_rows == 0)
	num_rows = 1000;
  
  var w = new Window ();
  var hbox = new Box(Orientation.HORIZONTAL, 0);
  w.add (hbox);

  var scrolled = new ScrolledWindow (null, null);
  scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
  hbox.add (scrolled);

  var scrolled_box = new Box(Orientation.VERTICAL, 0);
  scrolled.add_with_viewport (scrolled_box);

  var label = new Label ("This is \na LABEL\nwith rows");
  scrolled_box.add (label);
  
  var list = new ListBox();
  scrolled_box.add (list);
  list.set_adjustment (scrolled.get_vadjustment ());

  for (int i = 0; i < num_rows; i++) {
	var row = new Row ();
	list.add (row);
  }
  var vbox = new Box(Orientation.VERTICAL, 0);
  hbox.add (vbox);

  var b = new Button.with_label ("sort");
  vbox.add (b);
  b.clicked.connect ( () => {
		  list.set_sort_func (compare);
	  });

  b = new Button.with_label ("filter");
  vbox.add (b);
  b.clicked.connect ( () => {
		  list.set_filter_func (filter);
	  });

  b = new Button.with_label ("unfilter");
  vbox.add (b);
  b.clicked.connect ( () => {
		  list.set_filter_func (null);
	  });

  w.show_all ();


  Gtk.main ();

  return 0;
}
