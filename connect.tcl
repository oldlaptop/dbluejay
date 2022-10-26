#! /usr/bin/env tclsh

package require Tcl 8.5 ;# dict, {*}
package require Tk 8.5 ;# ttk
package require tdbc

package require cargocult::tk
package require cargocult::widgets
package require snit 2.2

namespace eval dbluejay {

# Knob widgets: allow the user to twiddle the various divers knobs that pertain
# to TDBC database connections. Except as noted, the megawidgets in this
# namespace correspond to TDBC drivers of the same names. Each widget is
# expected to support the connect method, which should return a dict of the form
# expected by dbluejay::metabrowser's add_connection method, hopefully
# describing a brand-new TDBC database connection that matches the user's
# specifications.
namespace eval knobs {
	snit::widgetadaptor mysql {
		delegate method * to hull
		delegate option * to hull

		constructor {args} {
			installhull using ::cargocult::optionlist -rows {
				host Host: ttk::entry {} 0 localhost

				port Port: ttk::spinbox {
					-from 0 -to 65536 -increment 1
				} 0 {3306}

				socket Socket: ttk::entry {} 0 {}
				user Username: ttk::entry {} 0 {}
				password Password: ttk::entry {-show *} 0 {}
				database Database: ttk::entry {} 0 {}
				ssl_ca {TLS CA:} ttk::entry {} 0 {}
				ssl_capath {TLS CA search path:} ttk::entry {} 0 {}
				ssl_cert {TLS certificate:} ttk::entry {} 0 {}
				ssl_cipher {TLS cipher:} ttk::entry {} 0 {}
				ssl_key {TLS key:} ttk::entry {} 0 {}
			}

			$self configurelist $args
		}

		method connect {} {
			tdbc::mysql::connection new {*}[$self option_list]
		}

		method personality {} {
			return information_schema
		}
	}

	snit::widget odbc {
		hulltype ttk::frame
		component optrows ;# cargocult::dynrows

		delegate method * to hull
		delegate option * to hull

		variable mode ;# Driver/DSN
		variable Driver {}
		variable DSN {}
		variable connstr {}
		variable personality {none}

		constructor {args} {
			ttk::radiobutton $win.drivercheck -text Driver -variable [
				myvar mode
			] -value Driver -command [mymethod Gen_connstr]
			ttk::combobox $win.drivers -values [
				dict keys [tdbc::odbc::drivers]
			] -textvariable [myvar Driver] -validatecommand [
				mymethod Gen_connstr
			] -validate focus

			ttk::radiobutton $win.dsncheck -text {Data Source} -variable [
				myvar mode
			] -value DSN -command [mymethod Gen_connstr]
			ttk::combobox $win.dsns -values [
				dict keys [tdbc::odbc::datasources]
			] -textvariable [myvar DSN] -validatecommand [
				mymethod Gen_connstr
			] -validate focus

			ttk::label $win.personalityl -text {SQL personality:}
			ttk::combobox $win.personality -textvariable [
				myvar personality
			] -state readonly -values [
				::dbluejay::personality::generic_personalities
			]

			install optrows using cargocult::dynrows $win.optrows \
				-newrow cargocult::kvpair -rowopts [list \
					-key_validatecommand [mymethod Gen_connstr] \
					-key_validate focus \
					-value_validatecommand [mymethod Gen_connstr] \
					-value_validate focus
				]

			foreach {tag event} [list \
				$win <<ComboboxSelected>> \
				$optrows <<NewDynrow>> \
				$optrows <<RmDynrow>>
			] {
				bind $tag $event [list after idle [mymethod Gen_connstr]]
			}

			set mode Driver
			set Driver [lindex [dict keys [tdbc::odbc::drivers]] 0]
			set DSN [lindex [dict keys [tdbc::odbc::datasources]] 0]

			$self Gen_connstr

			ttk::entry $win.connstren -textvariable [myvar connstr]

			grid $win.drivercheck  $win.drivers     $win.dsncheck $win.dsns -sticky new
			grid $win.personalityl $win.personality x             x         -sticky ew
			grid $optrows          -                -             -         -sticky nsew
			grid $win.connstren    -                -             -         -sticky sew

			grid rowconfigure $win 2 -weight 1
			grid columnconfigure $win {1 3} -weight 1
			cargocult::pad_grid_widgets [winfo children $win]

			$self configurelist $args
		}

		# Translate the various knobs into an ODBC connection string.
		method Gen_connstr {} {
			dict set conndict $mode [set $mode]
			foreach row [$optrows rows] {
				dict set conndict [$row cget -key] [$row cget -value]
			}

			set connstr \;[join [lmap {key value} $conndict {
				lindex $key=$value
			}] \;]

			return true
		}

		method connect {} {
			$self Gen_connstr
			tdbc::odbc::connection new $connstr
		}

		method personality {} {
			return $personality
		}
	}

	snit::widgetadaptor postgres {
		delegate method * to hull
		delegate option * to hull

		constructor {args} {
			installhull using ::cargocult::optionlist -rows {
				host Hostname: ttk::entry {} 0 localhost
				hostaddr {IP address:} ttk::entry {} 0 127.0.0.1

				port Port: ttk::spinbox {
					-from 0 -to 65536 -increment 1
				} 0 {3306}

				user Username: ttk::entry {} 0 {}
				password Password: ttk::entry {-show *} 0 {}
				database Database: ttk::entry {} 0 {}
				options {Additional options:} ttk::entry {} 0 {}

				sslmode {SSL mode:} ttk::combobox {-values {
					disable
					allow
					prefer
					require
				}} 0 prefer

				service {Service name:} ttk::entry {} 0 {}
				tty {Debug TTY (obsolete):} ttk::entry {} 0 {}
			}

			$self configurelist $args
		}

		method connect {} {
			tdbc::postgres::connection new {*}[$self option_list]
		}

		method personality {} {
			# The plain information_schema personality will work,
			# but causes serious performance problems when postgres
			# happily includes every single built-in function in
			# information_schema.routines
			return postgres
		}
	}

	# Meant principally for *existing* databases, though it won't validate
	# that. (tk_getOpenFile refuses to create nonexistent files.)
	snit::widget sqlite3 {
		hulltype ttk::frame

		delegate method * to hull
		delegate option * to hull

		variable filename

		constructor {args} {
			ttk::label $win.filenamel -text "File:"
			ttk::entry $win.filenameen -textvariable [myvar filename]
			ttk::button $win.browse -text "Browse..." -command [
				mymethod Browse
			]

			grid $win.filenamel $win.filenameen -sticky new
			grid x              $win.browse     -sticky se

			grid rowconfigure $win {0 1} -weight 1
			grid columnconfigure $win 1 -weight 1
			::cargocult::pad_grid_widgets [winfo children $win]

			$self configurelist $args
		}

		method connect {} {
			tdbc::sqlite3::connection new $filename
		}

		method Browse {} {
			set filename [tk_getOpenFile -filetypes {
				{{SQLite databases} {.sqlite} BINA}
				{{SQLite databases} {.db}     BINA}
				{{All files}        *}
			} -parent $win -title "Select existing SQLite database file"]
		}

		method personality {} {
			return sqlite3
		}
	}

	# Generic widget allowing the user to specify a custom TDBC driver, by
	# specifying the name of a new package to load and a Tcl command to
	# evaluate to get a TDBC database handle. This is, by anybody's
	# standard, a very direct code-execution vector, and should presumably
	# be treated accordingly.
	snit::widget other {
		hulltype ttk::frame

		delegate method * to hull
		delegate option * to hull

		variable package
		variable conncmd
		variable personality none

		constructor {args} {
			ttk::label $win.packagel -text "Driver package name:"
			ttk::entry $win.packageen -textvariable [myvar package]

			ttk::label $win.conncmdl -text "Connection command:"
			ttk::entry $win.conncmden -textvariable [myvar conncmd]

			ttk::label $win.personalityl -text {SQL personality:}
			ttk::combobox $win.personality -textvariable [
				myvar personality
			] -state readonly -values [::dbluejay::personality::personalities]

			grid $win.packagel     $win.packageen   -sticky new
			grid $win.conncmdl     $win.conncmden   -sticky new
			grid $win.personalityl $win.personality -sticky new

			grid columnconfigure $win 1 -weight 1
			::cargocult::pad_grid_widgets [winfo children $win]

			$self configurelist $args
		}

		method connect {} {
			package require $package
			eval $conncmd
		}

		method personality {} {
			return $personality
		}
	}
}

# Top-level window wrapping one of the knobs widgets above, also used to twiddle
# driver-independent knobs (currently knob, singular, the connection's human-
# readable "nickname"). Generates the synthetic event <<NewConnection>> upon
# the user's choosing to create a new database connection (at which time this
# window will destroy itself), with its -data field containing a dict with the
# following keys:
#     db:          the new database connection's TDBC handle
#     nickname:    User-visible nickname of this connection
#     personality: Name of the database personality to use (see personality.tcl)
snit::widget connectdialog {
	hulltype toplevel

	component knobs ;# any member of dbluejay::knobs above

	delegate method * to hull
	delegate option * to hull

	# The name of a specific member of dbluejay::knobs to wrap, which as
	# explained above is either also the name of a TDBC driver or the word
	# "other".
	option -driver -readonly yes -default other

	variable nickname {}
	typevariable nickserial 0

	constructor {args} {
		$self configurelist $args

		set nickname "Unnamed [incr nickserial] ([$self cget -driver])"

		set f [ttk::frame $win.f]

		install knobs using knobs::[$self cget -driver] $f.knobs
		ttk::label $f.namel -text "Nickname:"
		ttk::entry $f.nameen -textvariable [myvar nickname]
		ttk::button $f.connect -text "Connect" -command [mymethod Connect]

		grid $knobs   -         -          -sticky nsew
		grid $f.namel $f.nameen $f.connect -sticky sew
		grid rowconfigure $f 0 -weight 1
		grid columnconfigure $f 1 -weight 1

		grid $f -sticky nsew
		grid rowconfigure $win 0 -weight 1
		grid columnconfigure $win 0 -weight 1
	}

	method Connect {} {
		event generate [winfo parent $win] <<NewConnection>> -data [
			dict create \
				db [$knobs connect] \
				nickname $nickname \
				personality [$knobs personality]
		]
		destroy $win
	}
}

variable KNOWN_DRIVERS {
	mysql {MySQL}
	odbc {ODBC}
	postgres {PostgreSQL}
	sqlite3 {Existing SQLite3 database}
}

variable loaded_drivers

# Load a TDBC driver by name (in KNOWN_DRIVERS above) and package name.
proc load_driver {name package} {
	variable loaded_drivers

	if {[catch [list package require $package] msg]} {
		return -code error "couldn't load $name driver: $msg"
	} else {
		dict set loaded_drivers $name $msg
		return $msg
	}
}

# Iterate over KNOWN_DRIVERS above, loading whichever among them can be loaded.
proc driversearch {} {
	variable KNOWN_DRIVERS

	foreach driver [dict keys $KNOWN_DRIVERS] {
		if {[catch [list load_driver $driver tdbc::$driver] msg]} {
			puts stderr "warning: $msg"
		}
	}
}

# Creates a [menu] with path $path containing options corresponding to each
# currently-loadable TDBC driver (and "other"), each of which spawns a
# connectdialog wrapping the appropriate knobs:: widget. connectdialogs will be
# modal with respect to $rootwin.
proc connectmenu {path rootwin} {
	variable KNOWN_DRIVERS
	variable loaded_drivers

	set menu [menu $path]

	driversearch
	dict for {driver version} $loaded_drivers {
		$menu add command -command [namespace code [
			list show_connectdialog $driver $rootwin
		]] -label [dict get $KNOWN_DRIVERS $driver]...

		if {$driver eq {sqlite3}} {
			$menu add command -command [
				namespace code [list new_sqlite $rootwin]
			] -label {New SQLite3 database...}
		}
	}

	$menu add command -command [namespace code [
		list show_connectdialog other $rootwin
	]] -label {Other TDBC driver...}
}

# Show a connectdialog widget wrapping the knobs:: member $driver, modal with
# respect to $rootwin.
proc show_connectdialog {driver rootwin} {
	set dialog [
		connectdialog $rootwin.[cargocult::gensym connectdialog] -driver $driver
	]

	cargocult::modalize $dialog $rootwin
}

# Open a tdbc::sqlite3::connection object on a new file chosen by the user, and
# generate a <<NewConnection>> event from $rootwin, with an appropriate dict in
# its -data field (as emitted by connectdialog).
proc new_sqlite {rootwin} {
	if {[set dbfile [tk_getSaveFile -filetypes {
		{{SQLite databases} {.sqlite} BINA}
		{{SQLite databases} {.db}     BINA}
		{{All files}        *}
	} -parent $rootwin -title "Create new SQLite database file"]] ne {}} {
		event generate $rootwin <<NewConnection>> -data [dict create db [
			tdbc::sqlite3::connection new $dbfile
		] nickname $dbfile personality sqlite3]
	}
}

} ;# namespace eval dbluejay
