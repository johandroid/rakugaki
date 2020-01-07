/*
* Copyright (c) 2019 Lains
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/
namespace Rakugaki {
	public class Point {
		public double x;
		public double y;
		public Point (double x, double y) {
			this.x = x;
			this.y = y;
		}
	}
	
	public class Path {
		public GLib.List<Point> points = null;
	}
	
	public class DrawingArea : Gtk.DrawingArea {
		public MainWindow win;
		public signal void stroke_added (double[] coordinates);
		public signal void stroke_removed (uint n_strokes);
		
		public GLib.List<Path> paths = new GLib.List<Path> ();
		public Path current_path = new Path ();
		
		private int ratio = 25;
		public int line_thickness = 5;
		public Gdk.RGBA line_color;
		public Gdk.RGBA grid_main_dot_color;
		public Gdk.RGBA grid_dot_color;
		public Gdk.RGBA background_color;
		public bool dirty {get; set;}
		public bool see_grid {get; set; default=true;}
		private bool inside {get; set; default=false;}
		private double cur_x;
		private double cur_y;
		
		public DrawingArea (MainWindow win) {
			this.win = win;
			this.expand = true;
			this.set_size_request(this.get_allocated_width(),this.get_allocated_height());
			
			this.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
			this.add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
			this.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK);
			this.add_events (Gdk.EventMask.LEAVE_NOTIFY_MASK);
			this.add_events (Gdk.EventMask.POINTER_MOTION_MASK);
			
			this.button_press_event.connect ((e) => {
				current_path = new Path ();
				current_path.points.append (new Point (e.x, e.y));
				paths.append (current_path);
				dirty = true;
				return false;
			});
			
			this.motion_notify_event.connect ((e) => {
				Gtk.Allocation allocation;
				get_allocation (out allocation);
				
				double x = e.x.clamp ((double)allocation.x,(double)(allocation.x + allocation.width));
				double y = e.y.clamp ((double)allocation.y,(double)(allocation.y + allocation.height));
				//Point last = current_path.points.last ().data;
				double dx = x;
				double dy = y;
				if (Math.sqrt (dx * dx + dy * dy) > 10.0) {
					current_path.points.append (new Point (x, y));
					queue_draw ();
				}
				return false;
			});
			
			this.button_release_event.connect ((e) => {
				Gtk.Allocation allocation;
				get_allocation (out allocation);
				double[] coordinates = new double[current_path.points.length () * 2];

				int i = 0;
				foreach (var point in current_path.points) {
					coordinates[i] = point.x / (double)allocation.width;
					coordinates[i + 1] = point.y / (double)allocation.height;
				}
				stroke_added (coordinates);
				
				current_path = null;
				return false;
			});
			
			this.draw.connect ((c) => {
				c.set_antialias (Cairo.Antialias.SUBPIXEL);
				draw_grid (c);
				find_mouse (c);
				draws (c);
				
				return false;
			});
		}
		
		
		// Drawing Section
		public void draw_circle(Cairo.Context c, double x, double y) {
			c.set_source_rgba (grid_dot_color.red, grid_dot_color.green, grid_dot_color.blue, 1);
			c.arc(x, y, 9, 0, 2.0*3.14);
			c.fill();
			c.set_source_rgba (background_color.red, background_color.green, background_color.blue, background_color.alpha);
			c.arc(x, y, 6, 0, 2.0*3.14);
			c.fill();
			c.set_source_rgba (grid_dot_color.red, grid_dot_color.green, grid_dot_color.blue, 1);
			c.arc(x, y, 3, 0, 2.0*3.14);
			c.fill();
			c.stroke();
		}
		public bool mouse_entered(Gdk.EventCrossing e) {
			cur_x = e.x;
			cur_y = e.y;
			inside = true;
			queue_draw();
			return true;
		}
		public bool mouse_left(Gdk.EventCrossing e) {
			cur_x = -100;
			cur_y = -100;
			inside = false;
			queue_draw();
			return true;
		}
		private void find_mouse(Cairo.Context c) {
			int h = this.get_allocated_height ();
			int w = this.get_allocated_width ();
			if((Math.fabs(cur_x) <= ((h * ratio)+ratio)+1) && (Math.fabs(cur_y) <= ((w * ratio)+ratio)+1)) {
				if(inside) {
					draw_circle(c,cur_x,cur_y);
				}
				return;
			}
		}
		
		private void draw_grid (Cairo.Context c) {
			if (see_grid == true) {
				int i, j;
				int h = this.get_allocated_height ();
				int w = this.get_allocated_width ();
				c.set_line_width (1);
				for (i = 0; i <= w / ratio; i++) {
					for (j = 0; j <= h / ratio; j++) {
						if (i % 4 == 0 && j % 4 == 0) {
							c.set_source_rgba (grid_main_dot_color.red, grid_main_dot_color.green, grid_main_dot_color.blue, 1);
							c.arc ((i+1)*ratio, (j+1)*ratio, 1.4, 0, 2*Math.PI);
							c.fill ();
						} else {
							c.set_source_rgba (grid_dot_color.red, grid_dot_color.green, grid_dot_color.blue, 1);
							c.arc ((i+1)*ratio, (j+1)*ratio, 1.0, 0, 2*Math.PI);
							c.fill ();
						}
					}
				}
			}
		}
		
		public void draws (Cairo.Context c) {
			c.set_line_width (line_thickness);
			c.set_fill_rule (Cairo.FillRule.EVEN_ODD);
			
			c.set_source_rgba (line_color.red, line_color.green, line_color.blue, 1);
			foreach (var path in paths) {
				Point first = path.points.first ().data;
				c.move_to (first.x, first.y);
				foreach (var point in path.points.next) {
					c.line_to (point.x, point.y);
				}
				c.stroke ();
			}
		}
		
		public void undo () {
			if (paths != null) {
				unowned List<Path> last = paths.last ();
				unowned List<Path> prev = last.prev;
				paths.delete_link (last);
				if (current_path != null) {
					if (prev != null)
					current_path = prev.data;
					else
					current_path = null;
				}
				queue_draw ();
			}
		}
	}
	
	public class Dialog : Granite.MessageDialog {
		public MainWindow win;
		public Dialog () {
			Object (
			image_icon: new ThemedIcon ("dialog-information"),
			primary_text: _("Save Image?"),
			secondary_text: _("There are unsaved changes to the image. If you don't save, changes will be lost forever.")
			);
		}
		construct {
			var save = add_button (_("Save"), Gtk.ResponseType.OK);
			var cws = add_button (_("Close Without Saving"), Gtk.ResponseType.NO);
			var cancel = add_button (_("Cancel"), Gtk.ResponseType.CANCEL) as Gtk.Button;
			cancel.clicked.connect (() => { destroy (); });
		}
	}
	
	public class Widgets.UI : Gtk.VBox {
		public MainWindow window;
		public DrawingArea da;
		public EditableLabel line_thickness_label;
		public Gtk.ColorButton line_color_button;
		
		public signal void stroke_added (double[] coordinates);
		public signal void stroke_removed (uint n_strokes);
		
		public UI (MainWindow win) {
			this.window = win;

			da = new DrawingArea (win);
			
			da.stroke_added.connect ((coordinates) => {
				stroke_added (coordinates);
			});
			da.stroke_removed.connect ((n_strokes) => {
				stroke_removed (n_strokes);
			});
			
			key_press_event.connect ((e) => {
				uint keycode = e.hardware_keycode;
				
				if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
					if ((e.state & Gdk.ModifierType.SHIFT_MASK) != 0) {
						if (match_keycode (Gdk.Key.parenleft, keycode)) {
							if (da.line_thickness > 5) {
								da.line_thickness -= 5;
								line_thickness_label.text = da.line_thickness.to_string ();
								da.queue_draw ();
							} else if (da.line_thickness < 5) {
								da.line_thickness = 5;
								line_thickness_label.text = da.line_thickness.to_string ();
								da.queue_draw ();
							}
						}
						
						if (match_keycode (Gdk.Key.parenright, keycode)) {
							if (da.line_thickness != 50) {
								da.line_thickness += 5;
								line_thickness_label.text = da.line_thickness.to_string ();
								da.queue_draw ();
							} else {
								da.line_thickness = 5;
								line_thickness_label.text = da.line_thickness.to_string ();
								da.queue_draw ();
							}
						}
					}
				}
				return false;
			});
			
			var actionbar = new Gtk.ActionBar ();
			actionbar.get_style_context ().add_class ("dm-actionbar");
			
			var new_button = new Gtk.Button ();
			new_button.has_tooltip = true;
			new_button.set_image (new Gtk.Image.from_icon_name ("document-new-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			new_button.tooltip_text = (_("New file"));
			
			new_button.clicked.connect ((e) => {
				clear ();
			});
			
			actionbar.pack_start (new_button);
			
			var save_button = new Gtk.Button ();
			save_button.set_image (new Gtk.Image.from_icon_name ("document-save-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			save_button.has_tooltip = true;
			save_button.tooltip_text = (_("Save file"));
			
			save_button.clicked.connect ((e) => {
				try {
					save ();
				} catch (Error e) {
					warning ("Unexpected error during save: " + e.message);
				}
			});
			
			actionbar.pack_start (save_button);
			
			var undo_button = new Gtk.Button ();
			undo_button.set_image (new Gtk.Image.from_icon_name ("edit-undo-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			undo_button.has_tooltip = true;
			undo_button.tooltip_text = (_("Undo Last Line"));
			
			undo_button.clicked.connect ((e) => {
				da.undo ();
				da.current_path = new Path ();
				da.queue_draw ();
			});
			
			actionbar.pack_start (undo_button);
			
			line_color_button = new Gtk.ColorButton ();
			line_color_button.margin_start = 6;
			line_color_button.height_request = 24;
			line_color_button.width_request = 24;
			line_color_button.show_editor = true;
			line_color_button.get_style_context ().add_class ("dm-clrbtn");
			line_color_button.get_style_context ().remove_class ("color");
			line_color_button.tooltip_text = (_("Line Color"));
			actionbar.pack_start (line_color_button);
			
			line_color_button.color_set.connect ((e) => {
				da.line_color = line_color_button.rgba;
				da.queue_draw ();
			});
			
			var line_thickness_button = new Gtk.Button ();
			line_thickness_button.set_image (new Gtk.Image.from_icon_name ("line-thickness-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			line_thickness_button.has_tooltip = true;
			line_thickness_button.tooltip_text = (_("Change Line Thickness"));
			line_thickness_label = new EditableLabel (da.line_thickness.to_string());
			line_thickness_label.get_style_context ().add_class ("dm-text");
			line_thickness_label.valign = Gtk.Align.CENTER;
			line_thickness_label.hexpand = false;
			line_thickness_label.margin_top = 3;
			
			line_thickness_button.clicked.connect ((e) => {
				if (da.line_thickness < 50) {
					da.line_thickness++;
					line_thickness_label.text = da.line_thickness.to_string ();
					da.queue_draw ();
				} else {
					da.line_thickness = 5;
					line_thickness_label.text = da.line_thickness.to_string ();
					da.queue_draw ();
				}
			});
			
			line_thickness_label.changed.connect (() => {
				if (int.parse(line_thickness_label.title.get_label ()) > 50 || int.parse(line_thickness_label.title.get_label ()) < 5) {
					da.line_thickness = 5;
					line_thickness_label.text = da.line_thickness.to_string ();
					da.queue_draw ();
				} else {
					da.line_thickness = int.parse(line_thickness_label.title.get_label ());
					line_thickness_label.text = da.line_thickness.to_string ();
					da.queue_draw ();
				}
			});
			
			var line_thickness_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
			line_thickness_box.pack_start (line_thickness_button);
			line_thickness_box.pack_start (line_thickness_label);
			
			actionbar.pack_start (line_thickness_box);
			
			var see_grid_button = new Gtk.Button ();
			see_grid_button.set_image (new Gtk.Image.from_icon_name ("grid-dots-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			see_grid_button.has_tooltip = true;
			see_grid_button.tooltip_text = (_("Show/Hide Grid"));
			
			see_grid_button.clicked.connect ((e) => {
				if (da.see_grid == true) {
					da.see_grid = false;
				} else if (da.see_grid == false) {
					da.see_grid = true;
				}
				da.queue_draw ();
			});
			
			actionbar.pack_end (see_grid_button);
			
			this.pack_end (actionbar, false, false, 0);
			this.pack_start (da, true, true, 0);
			this.get_style_context ().add_class ("dm-grid");
			this.margin = 1;
			show_all ();
		}
		
		public void save () throws Error {
			debug ("Save as button pressed.");
			var file = display_save_dialog ();
			
			string path = file.get_path ();
			
			if (file == null) {
				debug ("User cancelled operation. Aborting.");
			} else {
				var png = new Cairo.ImageSurface (Cairo.Format.ARGB32, da.get_allocated_width(),da.get_allocated_height());
				Cairo.Context c = new Cairo.Context (png);
				da.draws (c);
				png.write_to_png (path + ".png");
				file = null;
			}
		}
		
		public Gtk.FileChooserDialog create_file_chooser (string title,
		Gtk.FileChooserAction action) {
			var chooser = new Gtk.FileChooserDialog (title, null, action);
			chooser.add_button ("_Cancel", Gtk.ResponseType.CANCEL);
			if (action == Gtk.FileChooserAction.OPEN) {
				chooser.add_button ("_Open", Gtk.ResponseType.ACCEPT);
			} else if (action == Gtk.FileChooserAction.SAVE) {
				chooser.add_button ("_Save", Gtk.ResponseType.ACCEPT);
				chooser.set_do_overwrite_confirmation (true);
			}
			var filter1 = new Gtk.FileFilter ();
			filter1.set_filter_name (_("PNG files"));
			filter1.add_pattern ("*.png");
			chooser.add_filter (filter1);
			
			var filter = new Gtk.FileFilter ();
			filter.set_filter_name (_("All files"));
			filter.add_pattern ("*");
			chooser.add_filter (filter);
			return chooser;
		}
		
		public File display_save_dialog () {
			var chooser = create_file_chooser (_("Save file"),
			Gtk.FileChooserAction.SAVE);
			File file = null;
			if (chooser.run () == Gtk.ResponseType.ACCEPT)
			file = chooser.get_file ();
			chooser.destroy();
			return file;
		}

		// IO Section
		private void clear () {
			var dialog = new Dialog ();
			dialog.transient_for = window;

			dialog.response.connect ((response_id) => {
				switch (response_id) {
					case Gtk.ResponseType.OK:
						debug ("User saves the file.");
						try {
							save ();
						} catch (Error e) {
							warning ("Unexpected error during save: " + e.message);
						}
						da.paths = null;
						da.current_path = new Path ();
						da.queue_draw ();
						da.dirty = false;
						stroke_removed (0);
						dialog.close ();
						break;
					case Gtk.ResponseType.NO:
						da.paths = null;
						da.current_path = new Path ();
						da.queue_draw ();
						stroke_removed (0);
						dialog.close ();
						break;
					case Gtk.ResponseType.CANCEL:
					case Gtk.ResponseType.CLOSE:
					case Gtk.ResponseType.DELETE_EVENT:
						dialog.close ();
						return;
					default:
						assert_not_reached ();
				}
			});


			if (da.dirty == true) {
				dialog.run ();
			}
		}
		
		#if VALA_0_42
		protected bool match_keycode (uint keyval, uint code) {
			#else
			protected bool match_keycode (int keyval, uint code) {
				#endif
				Gdk.KeymapKey [] keys;
				Gdk.Keymap keymap = Gdk.Keymap.get_for_display (Gdk.Display.get_default ());
				if (keymap.get_entries_for_keyval (keyval, out keys)) {
					foreach (var key in keys) {
						if (code == key.keycode)
						return true;
					}
				}
				
				return false;
			}
		}
	}