package Tk::LineNumberText;

use vars qw($VERSION);
$VERSION = '0.1';

use Tk;
use Tk::widgets qw(ROText);
use base qw(Tk::Frame);
use Carp;

Construct Tk::Widget 'LineNumberText';

sub Populate {

    my ( $self, $args ) = @_;

    $self->SUPER::Populate($args);

    $self->{'minwidth'}       = 5;
    $self->{'linenumshowing'} = 1;

    # Enough room for fixed 4 digit line number and an image (to come?)
    # IMO - Resizing the column on the fly looks crappy
    # I might make this configurable in a future version

    my $widget;
    if ( $widget = delete $args->{-widget} ) {
        unless ( eval "require Tk::${widget}" ) {
            carp "Tk::${widget} not found - defaulting to Tk::Text";
            $widget = 'Text';
        }
    }
    else {
        $widget = 'Text';
    }

    my $ltext = $self->ROText(
        -takefocus => 0,
        -cursor    => 'X_cursor',
        -bd        => 2,
        -relief    => 'flat',
        -width     => $self->{'minwidth'},
        -wrap      => 'none',
    );

    $self->{'ltext'} = $ltext;
    $ltext->tagConfigure( 'CURLINE', -data => 1 )
      ;    #tag to highlight line number of current cursor position
    my $ftext =
      $self->Scrolled($widget)
      ->grid( -row => 0, -column => 1, -sticky => 'nsew' );
    $self->{'rtext'} = my $rtext = $ftext->Subwidget('scrolled');

    $self->gridColumnconfigure( 1, -weight => 1 );
    $self->gridRowconfigure( 0, -weight => 1 );

    $self->Advertise( 'yscrollbar', $ftext->Subwidget('yscrollbar') );
    $self->Advertise( 'xscrollbar', $ftext->Subwidget('xscrollbar') );
    $self->Advertise( 'corner',     $ftext->Subwidget('corner') );
    $self->Advertise( 'frame',      $ftext );
    $self->Advertise( 'scrolled',   $rtext );
    $self->Advertise( 'text',       $rtext );
    $self->Advertise( 'linenum',    $ltext );

    # Set scrolling command to run the lineupdate..
    my $yscroll       = $self->Subwidget('yscrollbar');
    my $scrollcommand = $yscroll->cget( -command );

    $yscroll->configure(
        -command => sub {
            $scrollcommand->Call(@_);
            $self->_lineupdate;
        }
    );

    $self->ConfigSpecs(
        -linenumside      => [ 'METHOD',  undef,       undef,       'left' ],
        -linenumbg        => [ 'METHOD',  'numlinebg', 'numLinebg', '#dadada' ],
        -linenumfg        => [ 'METHOD',  'numlinefg', 'numLinefg', '#000000' ],
        -curlinehighlight => [ 'PASSIVE', undef,       undef,       1 ],
        -curlinebg        => [ 'METHOD',  undef,       undef,       '#00ffff' ],
        -curlinefg        => [ 'METHOD',  undef,       undef,       '#000000' ],
        -background       => [ $ftext,    undef,       undef,       undef ],
        -foreground       => [ $ftext,    undef,       undef,       undef ],
        -scrollbars       => [ $ftext,    undef,       undef,       'ose' ],
        -font             => ['CHILDREN'],
        -spacing1         => ['CHILDREN'],
        -spacing2         => ['CHILDREN'],
        -spacing3         => ['CHILDREN'],
        'DEFAULT'         => [$rtext],
    );

    $self->Delegates( 'DEFAULT' => 'scrolled' );

    #Bindings
    $ltext->bind( '<FocusIn>', sub { $rtext->focus } )
      ;    #no focus on line numbers for now..
    $ltext->bind( '<Map>', sub { $self->_lineupdate } );

    $rtext->bind( '<Configure>', sub { $self->_lineupdate } );
    $rtext->bind( '<KeyPress>',  sub { $self->_lineupdate } );
    $rtext->bind( '<ButtonPress>',
        sub { $self->{'rtext'}->{'origx'} = undef; $self->_lineupdate } );
    $rtext->bind( '<Return>',          sub { $self->_lineupdate } );
    $rtext->bind( '<ButtonRelease-2>', sub { $self->_lineupdate } );
    $rtext->bind( '<B2-Motion>',       sub { $self->_lineupdate } );
    $rtext->bind( '<MouseWheel>',      sub { $self->_lineupdate } );
    if ( $Tk::platform eq 'unix' ) {
        $rtext->bind( '<4>', sub { $self->_lineupdate } );
        $rtext->bind( '<5>', sub { $self->_lineupdate } );
    }

    # Create aliases to the text widget methods..
    # Thanks to Slaven Rezic for this code - he saved myself much typing.
    my @textMethods =
      qw/insert delete Delete deleteBefore Contents deleteSelected
      deleteTextTaggedwith deleteToEndofLine FindAndReplaceAll GotoLineNumber
      Insert InsertKeypress InsertSelection insertTab openLine yview ReplaceSelectionsWith
      Transpose see/;
    if ( ref($rtext) eq 'TextUndo' ) {
        push( @textMethods, 'Load' );
    }
    for my $method (@textMethods) {
        no strict 'refs';
        *{$method} = sub {
            my $cw  = shift;
            my @arr = $cw->{'rtext'}->$method(@_);
            $cw->_lineupdate;
            @arr;
        };
    }
}    # end Populate

# Configure methods
# ------------------------------------------
sub linenumside
# ------------------------------------------
{
    my ( $w, $side ) = @_;
    return unless defined $side;
    $side = lc($side);
    return unless ( $side eq 'left' or $side eq 'right' );
    $w->{'side'} = $side;
    $w->hidelinenum;
    $w->showlinenum;
}

# ------------------------------------------
sub linenumbg
# ------------------------------------------
{
    return shift->{'ltext'}->configure( -bg => @_ );
}

# ------------------------------------------
sub linenumfg
# ------------------------------------------
{
    return shift->{'ltext'}->configure( -fg => @_ );
}

# ------------------------------------------
sub curlinebg
# ------------------------------------------
{
    return shift->{'ltext'}->tagConfigure( 'CURLINE', -background => @_ );
}

# ------------------------------------------
sub curlinefg
# ------------------------------------------
{
    return shift->{'ltext'}->tagConfigure( 'CURLINE', -foreground => @_ );
}

# Public Methods
# ------------------------------------------
sub showlinenum
# ------------------------------------------
{
    my ($w) = @_;
    return if ( $w->{'linenumshowing'} );
    my $col;
    ( $w->{'side'} eq 'right' ) ? ( $col = 2 ) : ( $col = 0 );
    $w->{'ltext'}->grid( -row => 0, -column => $col, -sticky => 'ns' );
    $w->{'linenumshowing'} = 1;
}

# ------------------------------------------
sub hidelinenum
# ------------------------------------------
{
    my ($w) = @_;
    return unless ( $w->{'linenumshowing'} );
    $w->{'ltext'}->gridForget;
    $w->{'linenumshowing'} = 0;
}

#Private Methods
# ------------------------------------------
sub _lineupdate
# ------------------------------------------
{
    my ($w) = @_;
    return
      unless ( $w->{'ltext'}->ismapped )
      ;    # Don't bother continuing if line numbers cannot be displayed

    my $idx1 = $w->{'rtext'}->index('@0,0'); # First visible line in text widget
    $w->{'rtext'}->see($idx1);
    my ( $dummy, $ypix ) = $w->{'rtext'}->dlineinfo($idx1);

    my $theight = $w->{'rtext'}->height;
    my $oldy = my $lastline = -99;    #ensure at least one number gets shown
    $w->{'ltext'}->delete( '1.0', 'end' );

    my @LineNum;
    my $insertidx = $w->{'rtext'}->index('insert');
    my ($insertLine) = split( /\./, $insertidx );
    my $font  = $w->{'ltext'}->cget( -font );
    my $fixed = $w->{'ltext'}->fontMetrics( $font, '-fixed' );

    my $ltextline = 0;

#bug - only show a line number if it is on the same y value as the $line.0 index.

    while (1) {
        my $idx = $w->{'rtext'}->index( '@0,' . "$ypix" );
        ($realline) = split( /\./, $idx );
        my ( $x, $y, $wi, $he ) = $w->{'rtext'}->dlineinfo($idx);
        last unless defined $he;

        last if ( $oldy == $y );    #line is the same as the last one
        $oldy = $y;
        $ypix += $he;
        last if $ypix >= $theight;    #we have reached the end of the display
        last if ( $y == $ypix );

        $ltextline++;
        if ( $realline == $lastline ) {
            push( @LineNum, "\n" );
        }
        else {

            # pad numbers with spaces if fixed width font - it looks better
            # right justified.
            my $pad;
            if ($fixed) {
                $pad =
                  sprintf( "%*s", $w->{'ltext'}->cget( -width ) - 1,
                    $realline );

            #we leave some room 1 character for small images in future versions.
            }
            else {
                $pad = $realline;
            }
            push( @LineNum, "$pad\n" );
        }
        $lastline = $realline;
    }

    #ensure proper width for large line numbers (over 5 digits)
    my $neededwidth = length($lastline) + 1;
    my $ltextwidth  = $w->{'ltext'}->cget( -width );
    if ( $neededwidth > $ltextwidth ) {
        $w->{'ltext'}->configure( -width => $neededwidth );
    }
    elsif ( $ltextwidth > $w->{'minwidth'} && $neededwidth <= $w->{'minwidth'} )
    {
        $w->{'ltext'}->configure( -width => $w->{'minwidth'} );
    }
    elsif ( $neededwidth < $ltextwidth and $neededwidth > $w->{'minwidth'} ) {
        $w->{'ltext'}->configure( -width => $neededwidth );
    }

    #Finally insert the linenumbers..
    my $i = 1;
    my $highlightline;
    foreach my $ln (@LineNum) {
        $w->{'ltext'}->insert( 'end', $ln );
        if ( $ln =~ /\d+/ and $ln == $insertLine ) {
            $highlightline = $i;
        }
        $i++;
    }

    if ( $highlightline and $w->cget( -curlinehighlight ) ) {
        $w->{'ltext'}
          ->tagAdd( 'CURLINE', "$highlightline\.0", "$highlightline\.end" );
    }

}

1;

=head1 NAME

Tk::LineNumberText - Line numbers for your favorite Text-derived widget

=head1 SYNOPSIS

I<$linenumtext> = I<$parent>-E<gt>B<LineNumberText>(?I<options>?);

=head1 EXAMPLE

    use Tk;
    use Tk::LineNumberText;

    my $mw=tkinit;
    $mw->LineNumberText(
        -widget=>'Text',
        -wrap=>'word',
        -font=>['Courier',12],
        -bg=>'white')->pack(-fill=>'both', -expand=>1);
    MainLoop;

=head1 SUPER-CLASS

The C<LineNumberText> class is derived from the C<Frame> class.
However, this mega widget is comprised of a C<ROText> as a container for
the line numbers and a I<Scrolled> C<Text> widget (or any other widget
derived from L<Tk::Text|Tk::Text>). See DESCRIPTION below for details.

By default, all methods are delegated to the Text derived
widget which is created at instantiation. Therefore all the methods
for the widget chosen should be accessible through C<LineNumberText>.

=head1 DESCRIPTION

LineNumberText is a composite widget consisting of a ROText for the
linenumbers and any other derived widget from Tk::Text. It has been
tested using L<Text|Tk::Text>, L<CodeText|Tk::CodeText> and L<TextEdit|Tk::TextEdit>. Line numbers
will change as text is edited either programmatically or interactively.

As stated above, all options available to any C<Scrolled> Text-based
widget should be accessible. There are also some extra widget-specific
options as defined below.

=head1 WIDGET-SPECIFIC OPTIONS

=over 4

=item B<-widget>

B<Name> of the Tk::Text derived widget to use (such as Text, CodeText or
TextEdit). Note: This option needs to be passed as a string at creation.
Do B<not> pass a reference to an existing widget. This widget will be
created at instantiation and will default to a L<Tk::Text|Tk::Text>
if this option is not provided or if the widget chosen cannot be B<use>d.
This option B<cannot> be changed or queried using I<configure> or I<cget>
respectively.

=item B<-linenumfg>

Foreground color of the line numbers.

=item B<-linenumbg>

Background color of the line numbers.

=item B<-linenumside>

Specifies which side of the widget to place the line numbers. Must be
either left or right. Default is left.

=item B<-curlinehighlight>

Accepts a boolean value to determine whether or not to highlight the
line number of the insertion cursor. Default is 1 (on).

=item B<-curlinebg>

Background color of the line number for the current line of the insertion
cursor. Default is cyan.

=item B<-curlinefg>

Foreground color of the line number for the current line of the insertion
cursor. Default is black.

=back

=head1 WIDGET METHODS

As stated above, all methods default to the Text-derived widget. Otherwise
I<currently> only two extra methods exist.

=over 4

=item B<showlinenum>

Shows (Ie. grid) the linenumber widget.

=item B<hidelinenum>

Hides (Ie. gridForget) the linenumber widget.

=back

=head1 ADVERTISED WIDGETS

The following widgets are advertised:

=over

=item scrolled

The text or text-derived widget.

=item text

The text or text-derived widget. (Same as B<scrolled> above)

=item frame

The frame containing the scrollbars and text widget (As per the
L<Tk::Scrolled|Tk::Scrolled> method)

=item yscrollbar

The B<Scrollbar> widget using for vertical scrolling (if it exists)

=item xscrollbar

The B<Scrollbar> widget using for horizontal scrolling (if it exists)

=item corner

A frame in the corner between the vertical and horizontal scrollbars

=item linenum

The B<ROText> widget used for the line numbers.

=back

=head1 BUGS

There will always be a line number on the first display line. Even if
the text could actually be wrapped from a line which is off screen. I did
this to ensure that at least one line number is shown at all times.
I am considering this a beta-release until I receive some feedback.

=head1 TO DO

As suggested by Dean Arnold - I had all intentions of adding
availability of images on the line number margin, however it isn't as
simple as I first thought. So, time and effort have held me back from
completing this. I wanted to get I<something> on CPAN early. So I would
like to get some feedback on the approach I have taken.

Since all the widgets are advertised, you can feel free to sub-class or
just add your own bindings. I have intentionally left one character at
the end of each line number so images can be include using imageCreate
from Tk::Text.

=head1 AUTHOR

B<Jack Dunnigan> dunniganj@cpan.org

This code was inspired by ctext.tcl written by George Staplin.
This may be distributed under the same conditions as Perl.

=cut

