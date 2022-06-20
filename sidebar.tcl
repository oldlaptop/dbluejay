package require Tk 8.5
package require snit 2.2

namespace eval dbluejay {

# Single-column hierarchical ttk::treeview listing various interesting and
# uninteresting items contained within a TDBC-handled database.
snit::widgetadaptor dbsidebar {
	delegate method * to hull
	delegate option * to hull

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
		installhull using ttk::treeview -columns {
		} -show tree

		$self configurelist $args
	}

	# Erase and repopulate the tree with those interesting and uninteresting
	# database items. Returns true if something was actually done, false if
	# -db was empty and therefore nothing was done
	method update {} {
		if {[info command [$self cget -db]] eq {}} {
			return false
		}

		$hull delete [$hull children {}]

		# All personalities have the tdbc tables and columns methods
		$hull insert {} end -id tableroot -text Tables -open true
		foreach table [dict keys [[$self cget -db] tables]] {
			set tableitem [$hull insert tableroot end -text $table]
			dict for {column attrs} [[$self cget -db] columns $table] {
				$hull insert $tableitem end -text [
					format "%s %s %s" $column [
						dict get $attrs type
					] [
						expr {[dict get $attrs nullable]
							? {}
							: { NOT NULL}
						}
					]
				]
			}
		}

		# This represents the current extent of concrete plans for the
		# behavior of "personalities": each personality should one day
		# define a "frobs" method, returning a list of all the types of
		# frob its database is supposed to support (views, stored
		# procedures, that kind of thing). Each element of this list is
		# tentatively planned to be a dict with the following keys:
		#     name:   User-visible name for this frob
		#     method: Method of the personality ensemble that accepts
		#             a TDBC database handle and returns a list of all
		#             frobs of this type in the database; each element
		#             of this list is itself a dict with these keys:
		#                 name:     User-visible name of this item
		#                 subfrobs: List of user-visible strings to
		#                           display as sub-items of this item
		#                           (columns of a view?)
		foreach frob [[$self cget -personality] frobs] {
			set frobroot [$hull insert {} end -text [
				dict get $frob name
			]] -open true
			foreach fritem [
				[$self cget -personality] [
					dict get $frob method [$self cget -db]
				]
			] {
				set fritemroot [$hull insert $frobroot end -text [
					dict get $fritem name
				]
				foreach subfrob [dict get $fritem subfrobs] {
					$hull insert $fritemroot end -text $subfrob
				}
			}
		}

		return true
	}
}

} ;# namespace eval dbluejay
