#! /usr/bin/env tclsh

package require Tcl 8.5 ;# dict, {*}
package require Tk 8.5 ;# ttk
package require tdbc

package require cargocult::tk
package require cargocult::widgets
package require snit 2.2

namespace eval tkdb {

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
	}

	snit::widget odbc {
		hulltype ttk::frame
		component optrows

		delegate method * to hull
		delegate option * to hull

		variable mode ;# Driver/DSN
		variable Driver {}
		variable DSN {}
		variable connstr {}

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

			grid $win.drivercheck $win.drivers $win.dsncheck $win.dsns -sticky new
			grid $optrows         -            -             -         -sticky nsew
			grid $win.connstren   -            -             -         -sticky sew

			grid rowconfigure $win 1 -weight 1
			grid columnconfigure $win {1 3} -weight 1
			cargocult::pad_grid_widgets [winfo children $win]

			$self configurelist $args
		}

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
	}

	snit::widget other {
		hulltype ttk::frame

		delegate method * to hull
		delegate option * to hull

		variable package
		variable conncmd

		constructor {args} {
			ttk::label $win.packagel -text "Driver package name:"
			ttk::entry $win.packageen -textvariable [myvar package]

			ttk::label $win.conncmdl -text "Connection command:"
			ttk::entry $win.conncmden -textvariable [myvar conncmd]

			grid $win.packagel $win.packageen -sticky new
			grid $win.conncmdl $win.conncmden -sticky new

			grid columnconfigure $win 1 -weight 1
			::cargocult::pad_grid_widgets [winfo children $win]

			$self configurelist $args
		}

		method connect {} {
			package require $package
			eval $conncmd
		}
	}
}

snit::widget connectdialog {
	hulltype toplevel

	component knobs

	delegate method * to hull
	delegate option * to hull

	option -driver -readonly yes -default other

	constructor {args} {
		$self configurelist $args

		set f [ttk::frame $win.f]

		install knobs using knobs::[$self cget -driver] $f.knobs
		ttk::button $f.connect -text "Connect" -command [mymethod Connect]

		grid $knobs -sticky nsew
		grid $f.connect -sticky se
		grid rowconfigure $f 0 -weight 1
		grid columnconfigure $f 0 -weight 1

		grid $f -sticky nsew
		grid rowconfigure $win 0 -weight 1
		grid columnconfigure $win 0 -weight 1
	}

	method Connect {} {
		event generate . <<NewConnection>> -data [$knobs connect]
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

proc load_driver {name package} {
	variable loaded_drivers

	if {[catch [list package require $package] msg]} {
		return -code error "couldn't load $name driver: $msg"
	} else {
		dict set loaded_drivers $name $msg
		return $msg
	}
}

proc driversearch {} {
	variable KNOWN_DRIVERS

	foreach driver [dict keys $KNOWN_DRIVERS] {
		if {[catch [list load_driver $driver tdbc::$driver] msg]} {
			puts stderr "warning: $msg"
		}
	}
}

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

proc show_connectdialog {driver rootwin} {
	set dialog [
		connectdialog .[cargocult::gensym connectdialog] -driver $driver
	]

	cargocult::modalize $dialog $rootwin
}

proc new_sqlite {rootwin} {
	if {[set dbfile [tk_getSaveFile -filetypes {
		{{SQLite databases} {.sqlite} BINA}
		{{SQLite databases} {.db}     BINA}
		{{All files}        *}
	} -parent $rootwin -title "Create new SQLite database file"]] ne {}} {
		event generate . <<NewConnection>> -data [
			tdbc::sqlite3::connection new $dbfile
		]
	}
}

} ;# namespace eval tkdb
