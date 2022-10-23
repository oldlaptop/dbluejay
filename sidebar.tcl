package require Tk 8.5
package require snit 2.2

namespace eval dbluejay {

# Single-column hierarchical ttk::treeview and scrollbar listing various
# interesting and uninteresting items contained within a TDBC-handled database.
snit::widget dbsidebar {
	hulltype ttk::frame
	delegate method * to hull
	delegate option * to hull

	component tree   ;# ttk::treeview
	component scroll ;# ttk::scrollbar

	# TDBC database handle to introspect.
	option -db -default {} -configuremethod Set_db
	method Set_db {opt val} {
		set options($opt) $val
		after idle [mymethod update]
	}

	# no personality by default (empty string for all "methods")
	# See the body of the update method below for insight on the exciting
	# future of personalities.
	option -personality -default ::dbluejay::personality::none

	constructor {args} {
		install tree using ttk::treeview $win.tree -columns {
		} -show tree
		install scroll using ttk::scrollbar $win.scroll -command [
			list $tree yview
		]

		$tree configure -yscrollcommand [list $scroll set]

		grid $tree $scroll -sticky ns
		grid configure $tree -sticky nsew

		grid rowconfigure $win 0 -weight 1
		grid columnconfigure $win 0 -weight 1

		$self configurelist $args
	}

	# Erase and repopulate the tree with those interesting and uninteresting
	# database items. Returns true if something was actually done, false if
	# -db was empty and therefore nothing was done
	method update {} {
		if {[info command [$self cget -db]] eq {}} {
			return false
		}

		$tree delete [$tree children {}]

		foreach frob [[$self cget -personality] frobs] {
			set frobroot [$tree insert {} end -text [
				dict get $frob name
			] -open true]
			foreach fritem [
				[$self cget -personality] [
					dict get $frob method
				] [$self cget -db]
			] {
				set fritemroot [$tree insert $frobroot end -text [
					dict get $fritem name
				]]
				foreach subfrob [dict get $fritem subfrobs] {
					$tree insert $fritemroot end -text $subfrob
				}
			}
		}

		return true
	}
}

} ;# namespace eval dbluejay
