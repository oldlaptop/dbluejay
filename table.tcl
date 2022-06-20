package require Tk 8.5

package require snit 2.2
package require tdbc

namespace eval tkdb {

snit::widget rstable {
	hulltype ttk::frame

	delegate option * to hull
	delegate method * to hull

	component table
	component vscroll
	component hscroll

	option -rs -readonly yes -default {}
	option -chunksize -default 256

	constructor {args} {
		$self configurelist $args
		if {[$self cget -rs] eq {}} {
			return -code error "-rs is not optional"
		}

		install table using ttk::treeview $win.table -columns [
			[$self cget -rs] columns
		] -show headings
		install vscroll using ttk::scrollbar $win.vscroll \
			-orient vertical \
			-command [mymethod Vscroll_yview]
		install hscroll using ttk::scrollbar $win.hscroll \
			-orient horizontal \
			-command [list $table xview]

		$table configure -yscrollcommand [
			mymethod Vscroll_set
		] -xscrollcommand [
			list $hscroll set
		]

		foreach col [[$self cget -rs] columns] {
			$table heading $col -text $col
		}

		grid $table   $vscroll -sticky ns
		grid $hscroll x        -sticky ew

		grid configure $table -sticky nsew
		grid rowconfigure $win 0 -weight 1
		grid columnconfigure $win 0 -weight 1

		$self read [$self cget -chunksize]
	}

	method read {chunksize} {
		for {set index 0} {
			$index < $chunksize && [[$self cget -rs] nextlist row]
		} {incr index} {
			$table insert {} end -values $row
		}
	}

	method Check_read {} {
		if {[lindex [$vscroll get] 1] > 0.95} {
			$self read [$self cget -chunksize]
		}
	}

	method Vscroll_yview {args} {
		$table yview {*}$args
		$self Check_read
	}

	method Vscroll_set {args} {
		$vscroll set {*}$args
		$self Check_read
	}
}

snit::widgetadaptor rspager {
	delegate method * to hull
	delegate option * to hull

	option -db -default {apply {{args} {
		return -code error "please supply a tdbc handle"
	}}}

	option -sql -default {} -configuremethod Set_sql
	method Set_sql {opt val} {
		set options($opt) $val
		after idle [list $self update]
	}

	option -params -default {}

	option -chunksize -default 256

	variable rs_serial 0

	constructor {args} {
		installhull using ttk::notebook -height 300

		$self configurelist $args
	}

	method update {} {
		$self clear

		set sql_acc {}
		foreach token [tdbc::tokenize [$self cget -sql]] {
			if {$token eq {;}} {
				$self Execute $sql_acc
				set sql_acc {}
			} else {
				append sql_acc $token
			}
		}

		# There may be a trailing nonterminated statement; execute it
		# if so
		$self Execute $sql_acc

		event generate $win <<Executed>>
	}

	method clear {} {
		set rs_serial 0
		foreach tab [$hull tabs] {
			destroy $tab
		}
		foreach statement [[$self cget -db] statements] {
			$statement close
		}
	}

	method Execute {sql} {
		# Some drivers dislike null statements
		if {[string trim $sql] ne {}} {
			set statement [[$self cget -db] prepare $sql]
			$hull add [
				rstable $win.[::cargocult::gensym rs] -rs [
					$statement execute [$self cget -params]
				] -chunksize [$self cget -chunksize]
			] -text "Query [incr rs_serial]"
		}
	}
}

} ;# namespace eval tkdb
