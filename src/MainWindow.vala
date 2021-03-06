/*-
 * Copyright (c) 2017-2017 Artem Anufrij <artem.anufrij@live.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * The Noise authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Noise. This permission is above and beyond the permissions granted
 * by the GPL license by which Noise is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 *
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 */

namespace PlayMyMusic {
    public class MainWindow : Gtk.Window {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Settings settings;

        //CONTROLS
        Gtk.HeaderBar headerbar;
        Gtk.SearchEntry search_entry;
        Gtk.Spinner spinner;
        Gtk.Button play_button;
        Gtk.Button next_button;
        Gtk.Button previous_button;
        Gtk.MenuItem menu_item_rescan;
        Gtk.Image icon_play;
        Gtk.Image icon_pause;

        Gtk.Image artist_button;

        Granite.Widgets.ModeButton view_mode;
        Widgets.Views.AlbumsView albums_view;
        Widgets.Views.ArtistsView artists_view;
        Widgets.Views.RadiosView radios_view;
        Widgets.TrackTimeLine timeline;

        Notification desktop_notification;

        construct {
            settings = PlayMyMusic.Settings.get_default ();

            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.tag_discover_started.connect (() => {
                spinner.active = true;
                menu_item_rescan.sensitive = false;
            });
            library_manager.tag_discover_finished.connect (() => {
                spinner.active = false;
                menu_item_rescan.sensitive = true;
            });
            library_manager.added_new_artist.connect (() => {
                if (!artist_button.sensitive) {
                    artist_button.sensitive = true;
                }
            });

            library_manager.player_state_changed.connect ((state) => {
                play_button.sensitive = true;
                if (state == Gst.State.PLAYING) {
                    play_button.image = icon_pause;
                    play_button.tooltip_text = _("Pause");
                    if (library_manager.player.current_track != null) {
                        timeline.set_playing_track (library_manager.player.current_track);
                        headerbar.set_custom_title (timeline);
                        send_notification (library_manager.player.current_track);
                        previous_button.sensitive = true;
                        next_button.sensitive = true;
                    } else if (library_manager.player.current_file != null) {
                        timeline.set_playing_file (library_manager.player.current_file);
                        headerbar.set_custom_title (timeline);
                        previous_button.sensitive = false;
                        next_button.sensitive = false;
                    } else if (library_manager.player.current_radio != null) {
                        headerbar.title = library_manager.player.current_radio.title;
                        previous_button.sensitive = false;
                        next_button.sensitive = false;
                    }
                } else {
                    if (state == Gst.State.PAUSED) {
                        timeline.pause_playing ();
                    } else {
                        timeline.stop_playing ();
                        headerbar.set_custom_title (null);
                        headerbar.title = _("Play My Music");
                    }
                    play_button.image = icon_play;
                    play_button.tooltip_text = _("Play");
                }
            });
        }

        public MainWindow () {
            if (settings.window_maximized) {
                this.maximize ();
                this.set_default_size (1024, 720);
            } else {
                this.set_default_size (settings.window_width, settings.window_height);
            }
            this.window_position = Gtk.WindowPosition.CENTER;
            build_ui ();

            load_content_from_database.begin ((obj, res) => {
                albums_view.activate_by_id (settings.last_album_id);
                library_manager.scan_local_library (settings.library_location);
            });

            this.configure_event.connect ((event) => {
                settings.window_width = event.width;
                settings.window_height = event.height;
                artists_view.change_background ();
                return false;
            });

            this.destroy.connect (() => {
                settings.window_maximized = this.is_maximized;
                settings.view_index = view_mode.selected;
            });
        }

        public void build_ui () {
            // CONTENT
            var content = new Gtk.Stack ();

            headerbar = new Gtk.HeaderBar ();
            headerbar.title = _("Play My Music");
            headerbar.show_close_button = true;
            this.set_titlebar (headerbar);

            // PLAY BUTTONS
            icon_play = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            icon_pause = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);

            previous_button = new Gtk.Button.from_icon_name ("media-skip-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            previous_button.tooltip_text = _("Previous");
            previous_button.sensitive = false;
            previous_button.clicked.connect (() => {
                library_manager.player.prev ();
            });

            play_button = new Gtk.Button ();
            play_button.image = icon_play;
            play_button.tooltip_text = _("Play");
            play_button.sensitive = false;
            play_button.clicked.connect (() => {
                play ();
            });

            next_button = new Gtk.Button.from_icon_name ("media-skip-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            next_button.tooltip_text = _("Next");
            next_button.sensitive = false;
            next_button.clicked.connect (() => {
                library_manager.player.next ();
            });

            headerbar.pack_start (previous_button);
            headerbar.pack_start (play_button);
            headerbar.pack_start (next_button);

            // VIEW BUTTONS
            view_mode = new Granite.Widgets.ModeButton ();
            view_mode.valign = Gtk.Align.CENTER;
            view_mode.margin_left = 12;

            var album_button = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.BUTTON);
            album_button.tooltip_text = _("Albums");
            view_mode.append (album_button);

            artist_button = new Gtk.Image.from_icon_name ("avatar-default-symbolic", Gtk.IconSize.BUTTON);
            artist_button.tooltip_text = _("Artists");
            view_mode.append (artist_button);
            artist_button.sensitive = library_manager.artists.length () > 0;

            //view_mode.append_icon ("view-list-compact-symbolic", Gtk.IconSize.BUTTON);
            var radio_button = new Gtk.Image.from_icon_name ("network-cellular-connected-symbolic", Gtk.IconSize.BUTTON);
            radio_button.tooltip_text = _("Radio Stations");
            view_mode.append (radio_button);

            view_mode.mode_changed.connect (() => {
                switch (view_mode.selected) {
                    case 1:
                        if (artist_button.sensitive) {
                            content.set_visible_child_name ("artists");
                            search_entry.text = artists_view.filter;
                        } else {
                            view_mode.set_active (0);
                        }
                        break;
                    case 2:
                        if (library_manager.player.current_radio == null) {
                            search_entry.grab_focus ();
                        }
                        content.set_visible_child_name ("radios");
                        search_entry.text = radios_view.filter;
                        break;
                    default:
                        content.set_visible_child_name ("albums");
                        search_entry.text = albums_view.filter;
                        break;
                }
            });

            headerbar.pack_start (view_mode);

            // TIMELINE
            timeline = new Widgets.TrackTimeLine ();
            timeline.goto_current_track.connect ((track) => {
                if (track != null) {
                    switch (library_manager.player.play_mode) {
                        case PlayMyMusic.Services.PlayMode.ALBUM:
                            view_mode.set_active (0);
                            albums_view.activate_by_track (track);
                            break;
                        case PlayMyMusic.Services.PlayMode.ARTIST:
                            view_mode.set_active (1);
                            artists_view.activate_by_track (track);
                            break;
                    }
                }
            });

            // SETTINGS MENU
            var app_menu = new Gtk.MenuButton ();
            app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR));

            var settings_menu = new Gtk.Menu ();

            var menu_item_library = new Gtk.MenuItem.with_label(_("Change Music Folder…"));
            menu_item_library.activate.connect (() => {
                var folder = library_manager.choose_folder ();
                if(folder != null) {
                    settings.library_location = folder;
                    library_manager.scan_local_library (folder);
                }
            });

            var menu_item_import = new Gtk.MenuItem.with_label (_("Import Music…"));
            menu_item_import.activate.connect (() => {
                var folder = library_manager.choose_folder ();
                if(folder != null) {
                    library_manager.scan_local_library (folder);
                }
            });

            menu_item_rescan = new Gtk.MenuItem.with_label (_("Rescan Library"));
            menu_item_rescan.activate.connect (() => {
                settings.last_artist_id = 0;
                settings.last_album_id = 0;
                view_mode.set_active (0);
                artist_button.sensitive = false;
                albums_view.reset ();
                artists_view.reset ();
                radios_view.reset ();
                library_manager.rescan_library ();
            });

            settings_menu.append (menu_item_library);
            settings_menu.append (menu_item_import);
            settings_menu.append (new Gtk.SeparatorMenuItem ());
            settings_menu.append (menu_item_rescan);
            settings_menu.show_all ();

            app_menu.popup = settings_menu;
            headerbar.pack_end (app_menu);

            // SEARCH ENTRY
            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Search Music");
            search_entry.margin_right = 5;
            search_entry.search_changed.connect (() => {
                switch (view_mode.selected) {
                    case 1:
                        artists_view.filter = search_entry.text;
                        break;
                    case 2:
                        radios_view.filter = search_entry.text;
                        break;
                    default:
                        albums_view.filter = search_entry.text;
                        break;
                }
            });
            headerbar.pack_end (search_entry);

            // SPINNER
            spinner = new Gtk.Spinner ();
            headerbar.pack_end (spinner);

            albums_view = new Widgets.Views.AlbumsView ();
            albums_view.album_selected.connect (() => {
                previous_button.sensitive = true;
                play_button.sensitive = true;
                next_button.sensitive = true;
            });

            radios_view = new Widgets.Views.RadiosView ();

            artists_view = new Widgets.Views.ArtistsView ();
            artists_view.artist_selected.connect (() => {
                previous_button.sensitive = true;
                play_button.sensitive = true;
                next_button.sensitive = true;
            });

            content.add_named (albums_view, "albums");
            content.add_named (artists_view, "artists");
            content.add_named (radios_view, "radios");
            this.add (content);

            this.show_all ();

            albums_view.hide_album_details ();

            view_mode.set_active (settings.view_index);
            radios_view.unselect_all ();
            search_entry.grab_focus ();
        }

        private void send_notification (Objects.Track track) {
            if (!is_active) {
                if (desktop_notification == null) {
                    desktop_notification = new Notification ("");
                }
                desktop_notification.set_title (track.title);
                desktop_notification.set_body (_("<b>%s</b> by <b>%s</b>").printf (track.album.title, track.album.artist.name));
                try {
                    var icon = GLib.Icon.new_for_string (track.album.cover_path);
                    desktop_notification.set_icon (icon);
                } catch (Error err) {
                    warning (err.message);
                }
                this.application.send_notification (PlayMyMusicApp.instance.application_id, desktop_notification);
            }
        }

        private async void load_content_from_database () {
            foreach (var artist in library_manager.artists) {
                artists_view.add_artist (artist);
                foreach (var album in artist.albums) {
                    albums_view.add_album (album);
                }
            }
        }

        public void play () {
            if (library_manager.player.current_track != null || library_manager.player.current_radio != null || library_manager.player.current_file != null) {
                library_manager.player.toggle_playing ();
            } else {
                switch (view_mode.selected) {
                    case 0:
                        albums_view.play_selected_album ();
                        break;
                    case 1:
                        artists_view.play_selected_artist ();
                        break;
                }
            }
        }

        public void open_file (File file) {
            if (!albums_view.open_file (file.get_path ())) {
                library_manager.player.set_file (file);
            }
        }
    }
}
