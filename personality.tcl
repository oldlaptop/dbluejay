package require cargocult

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
			dict create name [{*}$tablecmd $table $table_attrs] subfrobs [
				lmap {column column_attrs} [$db columns $table] {
					{*}$columncmd $column $column_attrs
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

# Any database supporting the standard information schema, which is used to
# enumerate views and routines.
namespace eval information_schema {
	proc frobs {} {
		return {
			{name Tables method tables}
			{name Views method views}
			{name Routines method routines}
		}
	}
	namespace export frobs

	proc tables {db} { [namespace parent]::none::tables $db }
	namespace export tables

	# exclude_schemae is a list of schema names to exclude from the results;
	# if this personality is used directly we'll exclude the information
	# schema itself, but derived personalities may want to additionally
	# exclude internal views provided by their appropriate databases, such
	# as postgres' pg_catalog.
	proc views {db {exclude_schemae information_schema}} {
		# XXX: this snippet probably belongs in libcargocult
		set exclude_schemae_params [dict create]
		foreach schema $exclude_schemae {
			dict set exclude_schemae_params [::cargocult::gensym] $schema
		}

		lmap view_row [$db allrows [subst -novariables -nobackslashes {
			SELECT
				table_catalog,
				table_schema,
				table_name,
				is_updatable
			FROM information_schema.views
			-- XXX: the join probably belongs in libcargocult
			WHERE table_schema NOT IN ([join [lmap param [
				dict keys $exclude_schemae_params
			] {
				lindex :$param
			}] {, }])
		}] $exclude_schemae_params] {
			dict with view_row {}

			dict create name [format "%s.%s.%s%s" [
				::cargocult::sql_name $table_catalog
			] [
				::cargocult::sql_name $table_schema
			] [
				::cargocult::sql_name $table_name
			] [
				if {$is_updatable} {
					lindex { (updatable)}
				} else {
					lindex {}
				}
			]] subfrobs [lmap col_row [$db allrows {
				SELECT
					column_name,
					data_type
				FROM information_schema.columns
				WHERE table_name = :table_name
				ORDER BY ordinal_position ASC
			}] {
				dict with col_row {}

				format "%s %s" [
					::cargocult::sql_name $column_name
				] $data_type
			}]
		}
	}
	namespace export views

	# exclude_schemae is used precisely as with views above; while the
	# standard information schema doesn't define any routines to the
	# author's knowledge, that doesn't mean a database won't include
	# impertinent things in there for its own convenience (postgres), and
	# derived personalities may want to exclude system stuff.
	proc routines {db {exclude_schemae information_schema}} {
		set exclude_schemae_params [dict create]
		foreach schema $exclude_schemae {
			dict set exclude_schemae_params [::cargocult::gensym] $schema
		}

		lmap routine_row [$db allrows [subst -novariables -nobackslashes {
			/*
			 * The information schema provides a *lot* more
			 * information than this, much of which isn't
			 * necessarily pertinent in real database engines, or
			 * even present in important ones (e.g mysql/mariadb).
			 * We're constrained by the limited UI bandwidth
			 * available and therefore don't show very much.
			 */
			SELECT
				routine_catalog,
				routine_schema,
				routine_name,
				specific_name,
				routine_type,
				COALESCE(data_type, '(void)') AS data_type
			FROM information_schema.routines
			WHERE routine_schema NOT IN ([join [lmap param [
				dict keys $exclude_schemae_params
			] {
				lindex :$param
			}] {, }])
		}] $exclude_schemae_params] {
			dict with routine_row {}

			dict create name [format "%s %s.%s.%s (%s)" $data_type [
				::cargocult::sql_name $routine_catalog
			] [
				::cargocult::sql_name $routine_schema
			] [
				::cargocult::sql_name $routine_name
			] $routine_type] subfrobs [lmap param_row [$db allrows {
				SELECT
					parameter_mode,
					COALESCE(
						parameter_name,
						'(nameless)'
					) AS parameter_name,
					data_type
				FROM information_schema.parameters
				WHERE
					specific_name = :specific_name
					AND
					/*
					 * MySQL/MariaDB include a null row to
					 * represent a function's return value
					 */
					parameter_mode IS NOT NULL
				ORDER BY ordinal_position ASC
			}] {
				dict with param_row {}

				format "%s %s %s" $parameter_mode [
					::cargocult::sql_name $parameter_name
				] $data_type
			}]
		}
	}
	namespace export routines

	namespace ensemble create
}

namespace eval sqlite3 {
	# tdbc::sqlite3 lumps tables and views together, its tables method being
	# pretty clearly a shim over SELECT * FROM sqlite_master, right down to
	# including rootpage(!).
	proc frobs {} {
		return {
			{name Relations method tables}
		}
	}
	namespace export frobs

	# As for the none personality, but we want to render the names
	# differently, since we have a more-faithful rendering of the
	# database's name for each relation, and we want to indicate whether
	# each relation is a table or a view.
	proc tables {db} {
		[namespace parent]::none::tables $db {
			apply {{table attrs} {
				dict with attrs {
					format "%s (%s)" [::cargocult::sql_name [
						dict get $attrs tbl_name
					]] [
						dict get $attrs type
					]
				}
			}}
		}
	}
	namespace export tables

	namespace ensemble create
}

} ;# namespace eval dbluejay::personality
