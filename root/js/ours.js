// XXX ISSUES
// - Where to stash 'globals' like the 'session' var and 'dialogs' arrays?
// - Global obj/arrays representing state or manipulate & overload the DOM?
//   - dialogs we maintain a global array representing the current dialogs.
//     - I'm not sure we need to do this.  Instead use the $('.dialogs') or something to iterate?
//   - sessions we're messing about parsing html to extract the info we need (created_at).
//   - Which is better?
//
// Do stuff after document has finished loading
$(function() {

    // XXX Use the jquery :data mechanism to store data rather than a mirrored
    // local global dialogs variable

    // A dialog has a z index, and x,y,width,height properties.
    // A div containing a dialog, has an id of the form "dialogN"
    // We have a js array of dialog objects.
    // The div with id=dialogN contains the dialog described in dialogs[N]
    // The "Server" has a dialog table.
    //   One row per dialog
    //   Keyed on session and the dialog's z index.
    // We attempt to update the database whenever a dialog is
    //   Added
    //   Deleted
    //   Moved
    //   Resized
    //   Pod page is changed

    var session = new_session_id();
    var dialogs = [];
    var timeout;

    inject_dialog_nav();
    init_session();
    upgrade_link_actions();
    upgrade_search_form();

    // Fade out, then set a 'loading message', then show that
    // Finally, once all the above has completed, load the results page.
    function upgrade_search_form() {
        $('#search').submit(function() {
            var url = '/search/?inline=1&q='+escape($('#query').val());
            $('#wrap').fadeOut('fast', function() {
                $('#wrap').html('<span id=loading>loading ...</span>')
                          .show('fast', function() { $('#wrap').load(url) });
            })
            return false;
        })
    };

    function upgrade_link_actions() {
        $('.hit h3 a').live('click', function (a) {
            if (!dialogs.length) create_dialog();

            // Find the dialog that is top in the stack
            var id = find_top_dialog_id();
            $('#dialog' + id)
                .html('Loading ...')
                .load(this.href)
                .dialog('option', 'title', this.text)
                .dialog('open');
            dialogs[id].pod   = this.search.substring(1);
            dialogs[id].title = this.text;
            save_dialog_state(dialogs[id], 'save');
            return false;
        });
    }

    function inject_dialog_nav() {
        $('#top-nav .inner')
            .append('| <a id=new-dialog>+ dialog</a> | <div id=new-session />');
        $('#new-dialog').click(function() {
            create_dialog({
                open: true,
                body: "<p>Click a search result to view it's POD here.</p><p>You can drag this window around and resize it.</p>",
            })
        });
    }

    function find_top_dialog_id() {
        for (d in dialogs)
            if (dialogs[d].z == dialogs.length - 1) return d;
    }

    // Make post to server to save current dialog state
    function save_dialog_state(dialog, action) {
        delete dialog.needs_saving;
        $.post('/dialog',
            jQuery.extend({'action': action}, dialog)
        );
    }

    function get_id(dialog) { return dialog.id.substring(6, dialog.id.length) }

    // http://docs.jquery.com/UI/Dialog
    function create_dialog(properties) {

        if (!properties) properties = {};
        default_properties = {
            open: false,

        };
        // Defaults, overridden by anything in properties
        properties = jQuery.extend({
            open: false,
            title: 'Empty Window',
            body: 'Loading ...',
        }, properties);

        var dialog   = get_dialog_defaults(session);
        var z        = dialog.z;
        var id       = 'dialog'+z;
        var selector = '#'+id;
        dialogs[z]   = dialog;
        $('body').append('<div id='+id+' class=dialog />');

        $(selector).dialog({
            title: properties.title,
            height:   dialog.height,
            width:    dialog.width,
            position: [dialog.x, dialog.y],
            autoOpen: properties.open,
            focus: function() {
                var id = get_id(this);
                var dialog = dialogs[id];

                // Toggle the styles on the active/top dialog
                $('.ui-dialog').css({
                    border: '1px solid #ccc',
                    '-webkit-box-shadow': 'none',
                });
                $('.ui-dialog .ui-dialog-content').css({
                    color: '#444',
                });
                $('#dialog'+id).parent().css({
                    border: '2px solid #000',
                    '-webkit-box-shadow': '0 5px 10px #000',
                });
                $('#dialog'+id+'.ui-dialog-content').css({
                    color: '#000',
                });

                // Nothing to update if we're already the top dialog
                if (dialog.z == dialogs.length - 1) return;

                // All dialogs that were above the dialog that just gained focus
                // (and thus came to the 'front' of the stack), shift down one
                // in the list.  Update their state in the DB also.
                for (d in dialogs) {
                    if (dialogs[d].z > dialog.z) {
                        dialogs[d].z--;
                        save_dialog_state(dialogs[d], 'save');
                    }
                }
                // Bring the focused dialog to the front & update db state
                dialog.z = dialogs.length - 1;
                save_dialog_state(dialog, 'save');
            },
            close: function(evt) { close_dialog(dialogs, get_id(this)) },
            dragStop: function(evt, ui) {
                // This sets the dialogs position to where it currently is
                // but demostrates getting the position after a drag, and setting the position
                // $('#dialog').dialog('option', 'position', [ui.offset.left, ui.offset.top]);
                var dialog = dialogs[get_id(this)];
                dialog.x = ui.offset.left;
                dialog.y = ui.offset.top;
                if (dialog.pod) save_dialog_state(dialog, 'save');
            },
            resizeStop: function(evt, ui) {
                // Set width/height.  We loose scrollbars, so we'd need to reload the content
                // $('#dialog').dialog('option', 'width', ui.size.width).dialog('option', 'height', ui.size.height);
                var dialog = dialogs[get_id(this)];
                dialog.width = ui.size.width;
                dialog.height = ui.size.height;
                if (dialog.pod) save_dialog_state(dialog, 'save');
            }
        });
        $(selector)
            .html(properties.body)
            .scroll(function(evt) {
                var id              = get_id(this);
                var dialog          = dialogs[id];
                var node            = $('#dialog'+id);
                dialog.needs_saving = 1;
                dialog.top          = node.scrollTop();
                dialog.lft          = node.scrollLeft();
                clearTimeout(timeout);
                timeout = setTimeout(
                    function() {
                        clearTimeout(timeout);
                        for (d in dialogs)
                            if (dialogs[d].needs_saving)
                                save_dialog_state(dialogs[d], 'save');
                    },
                    500
                );
            });
    }

    function get_dialog_defaults(session) {
        var viewport = $(window);
        var dialog = {
            'session': session,
            z:       dialogs.length,
            width:   viewport.width() / 3,
            height:  viewport.height() - 100,
            y:       50,
            pod:     '',
        };
        dialog.x = viewport.width() - dialog.width - 40;
        return dialog;
    }

    function new_session_id() { return Math.floor(Math.random() * 1000000000) }

    // XXX This wants renaming.  'cleanup_dialog' or something
    function close_dialog(dialogs, id) {
        var dialog = dialogs[id];
        $('#dialog'+id).remove();

        // Delete it from the DB so we can shuffle higher dialogs down
        save_dialog_state(dialog, 'delete');

        // Shuffle higher id's & z dialogs down.
        // In our dialogs array and in the db
        for (d in dialogs) {
            if (dialogs[d].z > dialog.z) {
                dialogs[d].z--;
                save_dialog_state(dialogs[d], 'save');
            }
            if (d > id) {
                $('#dialog'+d).attr('id', 'dialog'+(d-1));
                dialogs[d-1] = dialogs[d];
            }

        }
        dialogs.pop();

        // If the deleted dialog wasn't the top dialog when it was
        // deleted, then we need to delete an additional db row.
        if (dialog.z < dialogs.length) {
            dialog.z = dialogs.length;
            save_dialog_state(dialog, 'delete');
        }
    }

    function init_session() {
        var q_session = $.query.get('session');
        $.ajax({
            type:     'GET',
            url:      '/session/list',
            dataType: 'json',
            success:  function( sessions, textStatus ) {
                if (sessions.length) {
                    var active = $.grep(sessions, function(n, i) { return n.active });
                    var obj = active.length ? active[0] : sessions[0];
                    if (q_session == 'new') {
                        sessions.push(new_session_object());
                    }
                    else if (q_session && String(q_session).match(/^\d+$/) && q_session <= sessions.length) {
                        session = sessions[ q_session - 1 ].session;
                    }
                    else {
                        session = obj.session;
                    }
                    load_dialogs_for_session(session);
                    inject_session_select_box(sessions);
                }
                else {
                    inject_session_select_box([ new_session_object() ]);
                }
            }
        });
    }

    function new_session_object() {
        var now = new Date();
        return {
            'session': session,
            'created_at': fmt_date(now) + ' ' + fmt_time(now),
        };
    }

    function load_dialogs_for_session(session) {
        $.ajax({
            type:     'GET',
            url:      '/session/dialogs/'+session+'?activate',
            // require async: 0 so init_session can tell when
            // querystring search != session search
            async:    0,
            dataType: 'json',
            success:  function( data, textStatus ) {
                for (d in data.dialogs) {
                    create_dialog();
                    var id     = find_top_dialog_id();
                    var obj    = $('#dialog' + id);
                    var dialog = dialogs[dialogs.length - 1] = data.dialogs[d];
                    obj
                        .html('Loading ...')
                        .load('/pod?'+escape(dialog.pod), {}, function() {
                            var dialog = dialogs[get_id(this)];
                            $(this)
                                .scrollTop(dialog.top)
                                .scrollLeft(dialog.lft);
                         })
                        .scrollTop(dialog.top)
                        .scrollLeft(dialog.lft)
                        .dialog('option', 'title',    dialog.title.replace(/\</g,'&lt;')
                                                                  .replace(/\>/g,'&gt;')
                                                                  .replace(/\"/g,'&quot;'))
                        .dialog('option', 'position', [dialog.x, dialog.y])
                        .dialog('option', 'width',    dialog.width)
                        .dialog('option', 'height',   dialog.height)
                        .dialog('open');
                }
            }
        });
    }

    function mk_option(spec) {
        var option = $(document.createElement('option'));
        option.text(spec.text);
        delete spec.text;
        option.attr(spec);
        return option;
    }

    function inject_session_select_box(sessions) {

        var select = $(document.createElement('select'));
        select.attr('id', 'session-select');
        var data = [
            { value: '',        text: 'Sessions' },
            { value: '_new',    text: 'Create new session',  'class': 'action first' },
            { value: '_delete', text: 'Delete this session', 'class': 'action' },
            { value: '_label',  text: 'Label this session',  'class': 'action' },
        ];
        for (d in data) select.append(mk_option(data[d]));
        select.append(mk_option({disabled: true}));
        for (s in sessions) {
            var spec = sessions[s];
            var text = spec.label ? spec.label : spec.created_at;
            select.append(mk_option({
                value: spec.session,
                'class': 'session',
                text: 'Session ' + (parseInt(s) + 1) + ': ' + text,
            }));
        }

        $('#new-session').replaceWith(select);
        $('#session-select option[value='+session+']').css({ background: '#cfc' });
        $('#session-select').val(session);

        $('#session-select').change(function() {
            switch($(this).val()) {
                case '_new':
                    new_session();
                    add_session_to_select(session);
                    $('#session-select').val(session);
                    break;
                case '_delete':
                    $('#session-select option[value='+session+']').remove();
                    sessions.splice(session_array_pos(session, sessions), 1);
                    while(dialogs.length) close_dialog(dialogs, 0);
                    if (sessions.length)
                        session = sessions[0].session;
                    else {
                        session = new_session_id();
                        add_session_to_select(session);
                    }
                    $('#session-select').val(session);
                    break;
                case '_label':
                    var label = window.prompt('Label for this session:', '');
                    $.post(
                        "/session/label",
                        { 'session': session, 'label': label }
                    );
                    var str = $('#session-select option[value='+session+']').text();
                    var pre = str.substr(0, str.indexOf(':') + 2);
                    $('#session-select option[value='+session+']').text(pre + label);
                    $('#session-select').val(session);
                    break;
                case '':
                    break;
                default:
                    destroy_session();
                    session = $(this).val();
                    load_dialogs_for_session(session);

                    $('#session-select option.session').css({ background: '#fff' });
                    $('#session-select option[value='+session+']')
                        .css({ background: '#cfc' });
                    $('#session-select').val(session);
            }
        });
    }

    function session_array_pos(target, sessions) {
        for (s in sessions)
            if (sessions[s].session == target)
                return s;
    }

    function pad(number) { return number > 10 ? number : '0' + number }

    function fmt_date(d) {
        return [d.getFullYear(), pad(d.getMonth() + 1), pad(d.getDate())]
            .join('-');
    }

    function fmt_time(d) {
        return [pad(d.getHours()), pad(d.getMinutes()), pad(d.getSeconds())]
            .join(':');
    }

    function add_session_to_select(session) {
        var now = new Date();
        var text = fmt_date(now) + ' ' + fmt_time(now);

        $('#session-select').append(mk_option({
            value: session,
            'class': 'session',
            text: 'Session ' + ($('#session-select option.session').length + 1) + ': ' + text,
        }));
    }

    // XXX I'm not sure we want to have the original link and then the select box
    // both offering "add session" options.  Ditch the link, rely on the select box
    // then inline this into the switch statement for the select onchange()
    function new_session() {
        destroy_session();
        session = new_session_id();
    }

    function destroy_session() {
        for (d in dialogs) $('#dialog'+d).dialog('destroy').remove();
        dialogs = [];
    }

});

