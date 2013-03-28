<#
.SYNOPSIS
	Create an HTML fragment file that when displayed, displays the source code
	with the various parts highlighted in different colors
.DESCRIPTION
	This programs takes as input a Powershell file and pretty prints it via
	<span style=''> codes to show different parts in different colors.
	This even prints the indents correctly and even allows for wrapping.
	Version 1.1
.PARAMETER InFile
	Powershell file to be listed. Required
.PARAMETER OutFile
	HTML fragment output file. If not supplied, will default to InFile with
	'.html appended and will be in the same directory as the input file.
.PARAMETER OptFile
	Not used currently
.PARAMETER TabEx
	Tab expansion.  The default is set to 2
.PARAMETER LineNums
	Whether we want line numbers or not
.NOTES
	Name: Pretty-Print.PS1
	Author: Bryan Price
	DateCreated: Nov2011
.LINK
	http://bytehead.wikidot.com/pretty-print-ps1
.EXAMPLE
	.\pretty-print.ps1 c:\User\Generic\PS\Print-Report.ps1 -TabEx 8

# requires 2.0
#>
param ($infile=$(Throw 'Paramater infile is required!'), $outfile, $optfile, [int] $tabex=2, [switch] $linenums)

# Declare our globals here.
$Global:oline = ''
$Global:curcol = 1
$Global:curlin = 1

<#

Thoughts

1.  Configuration file fun!
2.  Need to think about other options, full web page, or just the code.

#>

Function mung-htmlspace {
# This will preserve any indentation, on the left, or internal
# Repetitive spaces will be replaced by alternating non-break and regular spaces
  param($iline)
  if ($iline -eq $null) {
  	return ''
  }
  $iline = $iline.TrimEnd(' ')            	# Get rid of trailing spaces
  if ( $iline.indexof(' ') -eq -1 ) {
    return $iline                         	# No spaces, ignore
  }
  if ( $iline[0] -eq ' ' ) {								# If the first char is a space, make non-breakable
    $tline = '&nbsp;' + $iline[1]	   				# Keep 2nd char as is no matter what, can't be space
  } else {
    $tline = $iline[0] + $iline[1]					# Keep the first 2 chars as is.
  }
  $iline = $iline.remove(0,2)
  # Replace two spaces with non-break and regular
  $iline = $iline -replace '  ', '&nbsp; '	# Alternate &nb and reg
  $iline = $iline -replace '  ', ' &nbsp;'	# Fix remaining double spaces
  $tline = $tline + $iline                	# Tack on the remain line
  return $tline
}
		
Function start-new-line {
	begin {
		$numdigits = [int]([math]::log10($program.count) + 1)
		$lformat = "{0:D$numdigits}:"
	}
	process {
		if ($linenums.isPresent) {
			$pre = $lformat -f $Global:curlin								# Make the line number (in the default color) if needed
		} else {
			$pre = ""																				# Don't worry about line number
		}
		$Global:oline = mung-htmlspace($Global:oline)			# take care of HTML space issue
		$Global:oline = $Global:oline + '<br />'					# add in break
		add-content ($pre + $Global:oline) -path $outfile	# write out finished product
		$Global:oline = ''																# Reset output line
		$Global:curcol = 1																# Set column to beginning
		++$Global:curlin																	# Increment line tracking
	}
}

Function Space-out-line {
	param($tok)
	$i = [int] $tok.StartColumn												# Cheat
	while ($tok.StartLine -gt $Global:curlin) {				# Make sure we start on right line
 		start-new-line
	}
	if ($i -gt $Global:curcol) {											# Create spaces to where we need
		$Global:oline += (' ' * ($i - $Global:curcol))	
		$Global:curcol = $i															# Set our new column placeholder
	}
}

Function add-nomove {												# Add content without
	param($format)														# modifying the current column count
	$Global:oline += $format
}

Function add-token {
	param($token)
	[void] [System.Reflection.Assembly]::Loadwithpartialname("System.Web")
	$atcol = $token.StartColumn											# Temp column
	$atlen = $token.Length													# Temp length
	$atlin = $token.StartLine												# Temp line
	if ($token.Type -eq 'LineContinuation') {
		$atlen = 1																		# MS includes the `R`N as well.  Stupid
	}
	if ( ! ($token.StartLine -eq $token.EndLine) ) {	# Multiple lines, multiline comment
		while( $atlin -lt $token.EndLine ) {					# For each extra line
			$content = $program[$atlin-1].Substring($atcol - 1)
			$content = [System.Web.HttpUtility]::HtmlEncode($content) # Encode the string for HTML
			$Global:oline = $Global:oline + $content	
			start-new-line
			$atcol = 1																	# Reset column
			++$atlin																		# Bump to next line
			$atlen = $token.EndColumn - 1								# Length is now the last column
		}
	}
	# Process like a regular line
	$content = $program[$atlin-1].Substring($atcol - 1, $atlen)
	$content = [System.Web.HttpUtility]::HtmlEncode($content) # Encode the string for HTML
	$Global:oline = $Global:oline + $content
	$Global:curcol += $atlen
}

Function detabify-array {
	for ($i = 0; $i -lt $program.count; ++$i ) {
 		$line = $program[$i]									# get line
  	if ( ($x = ($line.indexof("`t")) ) -ne -1 ) {
    	for ( ; $x -ne -1 ; $x=($line.indexof("`t")) ) {
    		$line = $line.remove($x,1)
    		for ( $j = (($x+1) % $tabex) + 1; $j -ne 0; --$j ) {
        	$line = $line.insert($x,' ')		# pad out line to enough spaces.
     		}
			}
    	$program[$i] = $line
		}
	}
}

# Actual program start

$parser = [System.Management.Automation.PsParser]

# No leading $, we're comparing to Content

$autovars = @('$','?','^','_','Args','ConsoleFileName','Error','Event',
 'EventSubscriber','ExecutionContext','False','ForEach','Home','Host','Input',
 'LastExitCode','Matches','MyInvocation','NestedPromptLevel','NULL','PID',
 'Profile','PSBoundParameters','PsCmdlet','PsCulture','PSDebugContext','PsHome',
 'PSScriptRoot','PsUICulture','PsVersionTable','Pwd','Sender','ShellID',
 'SourceArgs','SourceEventArgs','This','True')

$infile = (Resolve-path $infile).Path
if ($outfile -eq $null) {
	$outfile = $infile + '.html'
} else {
	$outfile = (Resolve-path $outfile).Path
}
'<code>' | Set-Content $outfile
$program = Get-Content $infile
detabify-array

# Some programs sort on StartLine and StartColumn.  Don't see the need.
$pprogram = $parser::Tokenize($program, [ref] $null)

# To keep from massively inflating the output, anything that we want to keep black, we may not mark at all
# Keeping this generic so that I can modify to use CSS instead

$pret = `
@{'Attribute' = '<span style="color: black">';					# Black
	'Command' = '<span style="color: #A0522D">';					# Sienna
  'CommandArgument' = '<span style="color: #808080">';	# Gray
  'CommandParameter' = '<span style="color: #A719D6">';	# Blue Violet
  'Comment' = '<span style="color: #1C6C22">';					# Forest Green
  'GroupEnd' = '<span style="color: black">';						# Black
  'GroupStart' = '<span style="color: black">';					# Black
  'Keyword' = '<span style="color: #C75209">';					# Brown
  'LineContinuation' = '<span style="color: black">';		# Black
  'LoopLabel' = '<span style="color:#00FFFF">';					# Turquoise
  'Member' = '<span style="color: #2D61FB">';						# Light Blue
  'Number' = '<span style="color: #C71D18">';						# Fire Brick
  'Operator' = '<span style="color: #FF0000">';					# Red
  'Position' = '<span style="color: #FFFF00">';					# Yellow
  'StatementSeparator' = '<span style="color: black">';	# Black
  'String' = '<span style="color: #6802F6">';						# Dark Violet
  'Type' = '<span style="color: #FF8000">';							# Dark Orange
  'Variable' = '<span style="color: #0000FF">'; 				# Blue
  'AutoVar' = '<span style="color: #26FF00">'						# Bright Green
}

$espan = '</span>'

$post = @{'Attribute' = $espan;'Command' = $espan;
	'CommandArgument' = $espan; 'CommandParameter' = $espan;
	'Comment' = $espan; 'GroupEnd' = $espan;
	'GroupStart' = $espan; 'Keyword' = $espan;
	'LineContinuation' = $espan; 'LoopLabel' = $espan;
	'Member' = $espan; 'Number' = $espan;
	'Operator' = $espan; 'Position' = $espan;
	'StatementSeparator' = $espan; 'String' = $espan;
  'Type' = $espan; 'Variable' = $espan;
  'AutoVar' = $espan
}

foreach ( $token in $pprogram ) {
	if ($token.Type -ne 'NewLine') {
		Space-out-line $token
		$isauto = $false
		if($token.Type -eq 'Variable') {
:test	for($i = 0; $i -lt $autovars.Count; ++$i ) {
				if ( ($token.content.ToLower()) -eq ($autovars[$i].ToLower()) ) {
					$isauto = $true
					break
				}
			}
		}
		if ($isauto) {
			add-nomove($pret['AutoVar'])								# Add in AutoVars formatting
			add-token($token)														# Add token from $program array
			add-nomove($post['AutoVar'])								# Add in finsihing formatting
		}
		else {
			add-nomove($pret[$token.Type.toString()])		# Add in formatting before token
			add-token($token)							  						# Add token from $program array
			add-nomove($post[$token.Type.toString()])		# Add in finishing formatting
		}
	}
	else {
		start-new-line
	}
}
if ($Global:oline.length -gt 1) { 
	start-new-line                      						# Ensure we're at the end of the road
}
'</code>' | Add-Content $outfile
