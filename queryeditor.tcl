package require Tk 8.5
package require snit 2.2

namespace eval dbluejay {

snit::widget queryeditor {
	hulltype ttk::frame

	component editor
	component vscroll
	component hscroll
	component go

	delegate option * to hull
	delegate method * to hull

	variable chunksize 256

	constructor {args} {
		$self configurelist $args

		install editor using text $win.table
		install vscroll using ttk::scrollbar $win.vscroll -command [
			list $editor yview
		] -orient vertical
		install hscroll using ttk::scrollbar $win.hscroll -command [
			list $editor xview
		] -orient horizontal

		ttk::frame $win.cmd

		ttk::label $win.cmd.chunkprel -text "Fetch"
		ttk::spinbox $win.cmd.chunksb -textvariable [
			myvar chunksize
		] -width 6 -from 1 -to inf -increment 1 -validatecommand [
			mymethod Validate_chunksize %P
		] -validate focusout -invalidcommand [mymethod Bad_chunksize]
		ttk::label $win.cmd.chunkpostl -text "rows at once (\"inf\" is legal)"

		install go using ttk::button $win.cmd.go -text "Execute" -command [
			mymethod Execute
		]

		grid $win.cmd.chunkprel $win.cmd.chunksb $win.cmd.chunkpostl $win.cmd.go
		grid configure $win.cmd.go -sticky e
		grid columnconfigure $win.cmd 3 -weight 1

		grid $editor  $vscroll -sticky ns
		grid $hscroll x        -sticky ew
		grid $win.cmd -        -sticky ew

		grid configure $editor -sticky nsew

		grid rowconfigure $win 0 -weight 1
		grid columnconfigure $win 0 -weight 1
	}

	method sql {} { $editor get 1.0 end }
	method chunksize {} { set chunksize }
	method params {} { dict create }

	method Validate_chunksize {new_chunksize} {
		if {[string is double $new_chunksize] && $new_chunksize > 0} {
			$go state !disabled
			return 1
		} else {
			return 0
		}
	}
	method Bad_chunksize {} {
		$go state disabled
	}

	method Execute {} {
		event generate $win <<Execute>>
	}
}

} ;# namespace eval dbluejay
