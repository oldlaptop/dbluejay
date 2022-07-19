#! /usr/bin/env tclsh

package require Tk 8.5 ;# ttk

package require cargocult
package require snit 2.2

package provide application-dbluejay 0.1

namespace eval dbluejay {

# Megawidget for browsing a single database connection.
snit::widget browser {
	hulltype ttk::frame

	component sidebar ;# dbluejay::dbsidebar
	component table   ;# dbluejay::rspager
	component code    ;# dbluejay::queryeditor

	component lrsash ;# ttk::panedwindow
	component tbsash ;# ttk::panedwindow

	delegate method * to hull
	delegate option * to hull

	# The TDBC database handle to browse
	option -db -default {} -configuremethod Set_db
	method Set_db {opt val} {
		set options($opt) $val
		foreach widget [list $sidebar $table] {
			$widget configure $opt $val
		}
	}

	# If true, close the database connection in -db in the destructor.
	option -claimdb -default false

	constructor {args} {
		install lrsash using ttk::panedwindow $win.lrsash \
			-orient horizontal -width 640 -height 480
		install tbsash using ttk::panedwindow $win.lrsash.udsash \
			-orient vertical

		install sidebar using dbsidebar $win.lrsash.sb
		install table using rspager $win.lrsash.udsash.table
		install code using queryeditor $win.lrsash.udsash.code

		$lrsash add $sidebar -weight 0
		$lrsash add $tbsash -weight 1

		$tbsash add $table -weight 1
		$tbsash add $code -weight 1

		bind $code <<Execute>> [mymethod sync_sql]
		bind $table <<Executed>> [list $sidebar update]

		grid $lrsash -sticky nsew
		grid rowconfigure $win 0 -weight 1
		grid columnconfigure $win 0 -weight 1

		$self configurelist $args
	}

	destructor {
		if {[info command [$self cget -db]] ne {} && [$self cget -claimdb]} {
			[$self cget -db] close
		}
	}

	# Arrange for $table and $sidebar eventually to reflect exciting new
	# changes the user has hopefully provided in $code
	method sync_sql {} {
		$table configure \
			-sql [$code sql] \
			-chunksize [$code chunksize] \
			-params [$code params]
	}
}

# Top-level DBluejay window; creates and pages through multiple browser widgets
snit::widget metabrowser {
	hulltype toplevel

	component nb ;# cargocult::cnotebook, fills the entire toplevel

	delegate method * to hull
	delegate option * to hull

	constructor {args} {
		install nb using cargocult::cnotebook $win.nb

		menu $win.main
		connectmenu $win.main.connect $win
		$win.main add cascade -menu $win.main.connect -label Connect

		bind $win <<NewConnection>> [mymethod add_connection %d]

		$self configure -menu $win.main

		grid $win.nb -sticky nsew
		grid rowconfigure $win 0 -weight 1
		grid columnconfigure $win 0 -weight 1

		$self configurelist $args

		wm minsize $self 300 200
	}

	# Given a dict with the following keys:
	#
	# db:       a TDBC database handle
	# nickname: a human-readable name for the database handle
	#
	# adds a new browser tab over the database handle to $nb
	method add_connection {conn_info} {
		$nb add [browser $win.[cargocult::gensym browser] \
			-db [dict get $conn_info db] -claimdb true
		] -text [dict get $conn_info nickname]
	}
}

} ;# namespace eval dbluejay
