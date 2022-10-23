# This namespace defines the supported "personalities", or SQL dialects (so to
# speak). Each personality defines at least one kind of database object (or, as
# we'll be calling them throughout this file, "frobs") that dbluejay can work
# with, and how to format it for display to the user.
#
# The "public" (i.e. used by other parts of dbluejay) interface for a
# personality is as follows:
#
# A personality is a Tcl command (following the so-called "ensemble" pattern).
# Each one supports at least the subcommand "frobs", which accepts no arguments
# and returns a list of all the types of frob its database supports. Each
# element of this list is a dict with the following keys:
#     name:   User-visible plural name of this frob, for example "Tables".
#     method: A subcommand of this ensemble that accepts as its single parameter
#             a TDBC database handle and returns a list of all frobs of this
#             type in that database. Each element of this list is a dict with
#             the following keys:
#                 name:     User-visible singular name of this item; should
#                           generally also be its name within the database.
#                 subfrobs: List of user-visible strings to be displayed to the
#                           user as sub-items of this frob (generally things
#                           like the columns of a table).
#
# The baseline expectation is that every personality will at least define a
# "table" frob, and it seems likely that most personalities for specific
# database engines or TDBC drivers will also define at least a "view" frob.
namespace eval dbluejay::personality {

# Generic baseline personality: boring, but works on any conforming TDBC driver
namespace eval none {
	# All conforming TDBC drivers have the tables and columns methods.
	proc frobs {} {
		return {
			{name Tables method tables}
		}
	}
	namespace export frobs

	# Enumerate the tables under a conforming TDBC connection handle.
	# tablecmd and columncmd are command prefixes that are concatenated with
	# keys and values from the TDBC [$db tables] and [$db columns] methods
	# respectively and evaluated; their return values are then used as
	# user-visible representations of the table or column. The defaults
	# produce reasonable values based only on the behavior mandated in the
	# TDBC (TIP308) specification.
	#
	# Note that the tablecmd and columncmd arguments are more or less
	# 'private' extensions to the personality interface used by the rest of
	# dbluejay; they're here for the convenience of other personalities
	# that will want to enumerate tables themselves, but support extra
	# things their corresponding TDBC drivers do.
	proc tables {db {tablecmd format_table} {columncmd format_column}} {
		lmap {table table_attrs} [$db tables] {
			dict create name [$tablecmd $table $table_attrs] subfrobs [
				lmap {column column_attrs} [$db columns $table] {
					$columncmd $column $column_attrs
				}
			]
		}
	}
	namespace export tables

	# Format a table for display to the user; since the only thing the TDBC
	# spec mandates is that $table be the table's name, we just return that
	# unmodified (and ignore $attrs, which could be any random nonsense
	# in principle).
	proc format_table {table attrs} { return $table }

	# Format a column for display to the user. TDBC mandates that attrs be
	# a dict and provide at least the type, precision, scale, and nullable
	# keys; we only bother with type and nullability.
	proc format_column {column attrs} {
		format "%s %s %s" $column [
			dict get $attrs type
		] [
			expr {[dict get $attrs nullable]
				? {}
				: { NOT NULL}
			}
		]
	}

	namespace ensemble create
}

} ;# namespace eval dbluejay::personality
