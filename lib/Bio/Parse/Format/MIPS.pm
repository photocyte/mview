# Copyright (C) 1999-2019 Nigel P. Brown

# This file is part of MView.
# MView is released under license GPLv2, or any later version.

###########################################################################
package Bio::Parse::Format::MIPS;

use vars qw(@ISA);
use strict;

@ISA = qw(Bio::Parse::Record);


#delimit full MIPS entry
#my $MIPS_START          = '^\s*(?:\S+)?\s+MIPS:';
#my $MIPS_START          = '^(?:PileUp|\s*(?:\S+)?\s+MIPS:)';
my $MIPS_START          = '^>';
my $MIPS_END            = $MIPS_START;

#MIPS record types
my $MIPS_HEADER         = $MIPS_START;
my $MIPS_HEADERend      = '^L;';
my $MIPS_NAME           = $MIPS_HEADERend;
my $MIPS_NAMEend        = '^C;Alignment';
my $MIPS_ALIGNMENT      = '^\s*\d+';
my $MIPS_ALIGNMENTend   = $MIPS_START;
my $MIPS_Null           = '^\s*$';#'


#Consume one entry-worth of input on text stream associated with $file and
#return a new MIPS instance.
sub get_entry {
    my $text = shift;
    my $line = '';
    my $data = 0;

    while ($text->getline(\$line)) {

        #start of entry
        if ($line =~ /$MIPS_START/o and !$data) {
            $text->start_count();
            $data = 1;
            next;
        }

        #consume rest of stream
        if ($line =~ /$MIPS_END/o and $data) {
            $text->stop_count_at_start();
            last;
        }
    }
    return 0  unless $data;

    new Bio::Parse::Format::MIPS(undef, $text, $text->get_start(), $text->get_stop()-$text->get_start());
}

#Parse one entry
sub new {
    my $type = shift;
    if (@_ < 2) {
        #at least two args, ($offset, $bytes are optional).
        Bio::Util::Object::die($type, "new() invalid arguments:", @_);
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Scanner($self);

    while (defined ($line = $text->next_line)) {

        #HEADER lines
        if ($line =~ /$MIPS_HEADER/o) {
            $text->OLD_scan_until($MIPS_HEADERend, 'HEADER');
            next;
        }

        #consume data

        #NAME lines
        if ($line =~ /$MIPS_NAME/o) {
            $text->OLD_scan_until($MIPS_NAMEend, 'NAME');
            next;
        }

        #ALIGNMENT lines
        if ($line =~ /$MIPS_ALIGNMENT/o) {
            $text->OLD_scan_until($MIPS_ALIGNMENTend, 'ALIGNMENT');
            next;
        }

        #blank line or empty record: ignore
        next    if $line =~ /$MIPS_Null/o;

        #end of NAME section: ignore
        next    if $line =~ /$MIPS_NAMEend/o;

        #default
        $self->warn("unknown field: $line");
    }
    $self;#->examine;
}


###########################################################################
package Bio::Parse::Format::MIPS::HEADER;

use Bio::Parse::Strings qw(strip_english_newlines);

use vars qw(@ISA);

@ISA = qw(Bio::Parse::Record);

sub new {
    my $type = shift;
    if (@_ < 2) {
        #at least two args, ($offset, $bytes are optional).
        Bio::Util::Object::die($type, "new() invalid arguments:", @_);
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Scanner($self);

    $self->{'desc'} = '';

    #consume Name lines
    while (defined ($line = $text->next_line)) {

        #> line
        if ($line =~ /^>[^;]+;(\S+)/o) {
            $self->test_args(\$line, $1);
            $self->{'ac'} = $1;
            next;
        }

        #accumulate other lines
        $self->{'desc'} .= $line;
    }

    $self->warn("missing MIPS data\n")  unless exists $self->{'ac'};

    $self->{'desc'} = strip_english_newlines($self->{'desc'});

    $self;
}

sub dump_data {
    my ($self, $indent) = (@_, 0);
    my $x = ' ' x $indent;
    my $s = '';
    $s .= sprintf "$x%20s -> %s\n",   'ac',   $self->{'ac'};
    $s .= sprintf "$x%20s -> '%s'\n", 'desc', $self->{'desc'};
    return $s;
}


###########################################################################
package Bio::Parse::Format::MIPS::NAME;

use Bio::Parse::Strings qw(strip_english_newlines);

use vars qw(@ISA);

@ISA = qw(Bio::Parse::Record);

sub new {
    my $type = shift;
    if (@_ < 2) {
        #at least two args, ($offset, $bytes are optional).
        Bio::Util::Object::die($type, "new() invalid arguments:", @_);
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Scanner($self);

    $self->{'seq'}   = {};
    $self->{'order'} = [];

    #consume Name lines
    while (defined ($line = $text->next_line)) {

        if ($line =~ /^L;(\S+)\s+(.*)/o) {
            $self->test_args(\$line, $1,$2);
            $self->{'seq'}->{$1} = strip_english_newlines($2);
            push @{$self->{'order'}}, $1;
            next;
        }

        next  if $line =~ /$MIPS_Null/;

        #default
        $self->warn("unknown field: $line");
    }
    $self;
}

sub dump_data {
    my ($self, $indent) = (@_, 0);
    my $x = ' ' x $indent;
    my $s = '';
    foreach my $i (@{$self->{'order'}}) {
        $s .= sprintf "$x%20s -> %-15s %s=%s\n",
            'seq',  $i,
            'desc', $self->{'seq'}->{$i};
    }
    return $s;
}


###########################################################################
package Bio::Parse::Format::MIPS::ALIGNMENT;

use vars qw(@ISA);

@ISA = qw(Bio::Parse::Record);

sub new {
    my $type = shift;
    if (@_ < 2) {
        #at least two args, ($offset, $bytes are optional).
        Bio::Util::Object::die($type, "new() invalid arguments:", @_);
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Scanner($self);

    $self->{'seq'} = {};

    while (defined ($line = $text->next_line)) {

        #start/end positions
        next  if $line =~ /^\s*\d+[^0-9]*\d+\s*$/o;

        #id/sequence
        if ($line =~ /^\s*(\S+)\s+([^0-9]+)\s+\d+$/o) {
            $self->test_args(\$line, $1, $2);
            $self->{'seq'}->{$1} .= $2;
            next;
        }

        #default: ignore all other line types (site and consensus data)
    }

    foreach (keys %{$self->{'seq'}}) {
        $self->{'seq'}->{$_} =~ s/ //g;
    }

    $self;
}

sub dump_data {
    my ($self, $indent) = (@_, 0);
    my $x = ' ' x $indent;
    my $s = '';
    foreach my $i (sort keys %{$self->{'seq'}}) {
        $s .= sprintf "$x%20s -> %-15s =  %s\n", 'seq', $i, $self->{'seq'}->{$i};
    }
    return $s;
}


###########################################################################
1;
