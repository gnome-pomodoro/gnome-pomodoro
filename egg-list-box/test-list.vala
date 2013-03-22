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

public void update_separator (ref Widget? separator,
			      Widget widget,
			      Widget? before)
{
  if (before == null ||
      (widget is Label && (widget as Label).get_text () == "blah3")) {
    if (separator == null) {
      var hbox = new Box(Orientation.HORIZONTAL, 0);
      var l = new Label ("Separator");
      hbox.add (l);
      var b = new Button.with_label ("button");
      hbox.add (b);
      l.show ();
      b.show ();
      separator = hbox;
    }

    var hbox = separator as Box;
    var id = widget.get_data<int>("sort_id");
    var l = hbox.get_children ().data as Label;
    l.set_text ("Separator %d".printf (id));
  } else {
    separator = null;
  }
  print ("update separator => %p\n", separator);
}

public static int
compare_label (Widget a, Widget b) {
  var aa = a.get_data<int>("sort_id");
  var bb = b.get_data<int>("sort_id");
  return bb - aa;
}

public static int
compare_label_reverse (Widget a, Widget b) {
	return - compare_label (a, b);
}

public static bool
filter (Widget widget) {
	var text = (widget as Label).get_text ();
	return strcmp (text, "blah3") != 0;
}

public static int
main (string[] args) {

  Gtk.init (ref args);

  var w = new Window ();
  var hbox = new Box(Orientation.HORIZONTAL, 0);
  w.add (hbox);

  var list = new ListBox();
  hbox.add (list);

  list.child_activated.connect ( (child) => {
      print ("activated %p\n", child);
    });

  list.child_selected.connect ( (child) => {
      print ("selected %p\n", child);
    });

  var l = new Label ("blah4");
  l.set_data ("sort_id", 4);
  list.add (l);
  var l3 = new Label ("blah3");
  l3.set_data ("sort_id", 3);
  list.add (l3);
  l = new Label ("blah1");
  l.set_data ("sort_id", 1);
  list.add (l);
  l = new Label ("blah2");
  l.set_data ("sort_id", 2);
  list.add (l);

  var row_vbox = new Box (Orientation.VERTICAL, 0);
  var row_hbox = new Box (Orientation.HORIZONTAL, 0);
  row_vbox.set_data ("sort_id", 3);
  l = new Label ("da box for da man");
  row_hbox.add (l);
  var check = new CheckButton ();
  row_hbox.add (check);
  var button = new Button.with_label ("ya!");
  row_hbox.add (button);
  row_vbox.add (row_hbox);
  check = new CheckButton ();
  row_vbox.add (check);
  list.add (row_vbox);

  button = new Button.with_label ("focusable row");
  button.set_hexpand (false);
  button.set_halign (Align.START);
  list.add (button);

  var vbox = new Box(Orientation.VERTICAL, 0);
  hbox.add (vbox);

  var b = new Button.with_label ("sort");
  vbox.add (b);
  b.clicked.connect ( () => {
		  list.set_sort_func (compare_label);
	  });

  b = new Button.with_label ("reverse");
  vbox.add (b);
  b.clicked.connect ( () => {
		  list.set_sort_func (compare_label_reverse);
	  });

  b = new Button.with_label ("change");
  vbox.add (b);
  b.clicked.connect ( () => {
		  if (l3.get_text () == "blah3") {
			  l3.set_text ("blah5");
			  l3.set_data ("sort_id", 5);
		  } else {
			  l3.set_text ("blah3");
			  l3.set_data ("sort_id", 3);
		  }
		  list.child_changed (l3);
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

  int new_button_nr = 1;
  b = new Button.with_label ("add");
  vbox.add (b);
  b.clicked.connect ( () => {
		  var ll = new Label ("blah2 new %d".printf (new_button_nr));
		  l.set_data ("sort_id", new_button_nr);
		  new_button_nr++;

		  list.add (ll);
		  l.show ();
	  });

  b = new Button.with_label ("separate");
  vbox.add (b);
  b.clicked.connect ( () => {
		  list.set_separator_funcs (update_separator);
	  });

  b = new Button.with_label ("unseparate");
  vbox.add (b);
  b.clicked.connect ( () => {
		  list.set_separator_funcs (null);
	  });


  w.show_all ();

  var provider = new Gtk.CssProvider ();
  provider.load_from_data (
"""
EggListBox:prelight {
background-color: green;
}
EggListBox:active {
background-color: red;
}
""", -1);
  Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
					    provider,
					    600);

  Gtk.main ();

  return 0;
}
