package require Tk 8.5
package require snit 2.2

namespace eval dbluejay {

snit::widgetadaptor dbsidebar {
	delegate method * to hull
	delegate option * to hull

	option -db -default {} -configuremethod Set_db
	method Set_db {opt val} {
		set options($opt) $val
		after idle [mymethod update]
	}

	# no personality by default (empty string for all "methods")
	option -personality -default ::dbluejay::personality::none

	constructor {args} {
		installhull using ttk::treeview -columns {
		} -show tree

		$self configurelist $args
	}

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
