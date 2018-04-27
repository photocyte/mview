# -*- perl -*-
# Copyright (C) 2015-2018 Nigel P. Brown

###########################################################################
#
# Base classes for NCBI BLAST2 family.
#
# Handles: BLAST+ -outfmt 7
#
# BLAST (NCBI version 2) iterated searching uses 3 main record types:
#
#   HEADER        the header text
#   SEARCH {*}    passes of the search engine
#     RANK        the list of ordered high scoring hits
#     MATCH {*}   the set of alignments for a given hit
#       SUM         the summary lines for each hit
#       ALN {*}     each aligned fragment: score + alignment
#
###########################################################################
package Bio::Parse::Format::BLAST2_OF7;

use Bio::Parse::Format::BLAST;
use Bio::Parse::Format::BLAST2;

use strict;

use vars qw(@ISA

	    @VERSIONS

	    $ENTRY_START
	    $ENTRY_END

	    $HEADER_START
	    $HEADER_END
	   );

@ISA = qw(Bio::Parse::Format::BLAST);

@VERSIONS = (
	     '2of7' => [
                     'BLASTP',
                     'BLASTN',
		     'BLASTX',
		     'TBLASTN',
		     'TBLASTX',
		     'PSIBLAST',
		    ],
	    );

# BLAST -outfmt 7 HEADER format is:
#
# Upto blast version 2.4.0+
#
#  # PSIBLAST 2.2.28+
#  # Iteration: 1                  [note: psiblast only]
#  # Query: test
#  # Database: mito.1000.aa
#  # Fields: query id, subject id, % identity, alignment length, ...
#  # 65 hits found
# <data>\t<data>\t...
# <data>\t<data>\t...
# ...

# From blast version 2.5.0+
#
#  # PSIBLAST 2.5.0+
#  # Iteration: 1                  [note: psiblast only]
#  # Query: test
#  # Database: mito.1000.aa
#  # Fields: query acc., subject acc., % identity, alignment length, ...
#  # 65 hits found
# <data>\t<data>\t...
# <data>\t<data>\t...
# ...

# From blast version 2.6.0+
#
#  # PSIBLAST 2.6.0+
#  # Iteration: 1                  [note: psiblast only]
#  # Query: test
#  # Database: mito.1000.aa
#  # Fields: query acc.ver, subject acc.ver, % identity, alignment length, ...
#  # 65 hits found
# <data>\t<data>\t...
# <data>\t<data>\t...
# ...

# followed by
#
# default case: single search terminates with:
#  # BLAST processed 1 queries
#  <eof>

# psiblast searches repeat then terminate with:
#
#  <blank>
#  Search has CONVERGED!
#  # BLAST processed 2 queries
#  <eof>

my $NULL = '^\s*$';

my $PROGRAMS = "(?:" . join("|", @{$VERSIONS[1]}) . ")";

$ENTRY_START     = "^\# $PROGRAMS";
$ENTRY_END       = '^\# .*processed';

$HEADER_START    = $ENTRY_START;
$HEADER_END      = '^[^\#]';

my $SEARCH_START = "^[^\#][^\t]*\t";
my $SEARCH_END   = "^(?:$NULL|$HEADER_START|$ENTRY_END)";

my $FIELD_SKIP   = '-';
my $FIELD_MAP    = {  #blastp -help for -outfmt 7 fields
    #HEADER comment                   blast CL specifier   #CL 'std' specifier
    #-----------------------------------------------------------------------
    'query id'                        => 'qseqid',         #upto 2.4.0+
    'query gi'                        => 'qgi',
    'query acc.'                      => 'qacc',           #from 2.5.0+
    'query acc.ver'                   => 'qaccver',        #from 2.6.0+
    'query length'                    => 'qlen',
    'subject id'                      => 'sseqid',         #upto 2.4.0+
    'subject ids'                     => 'sallseqid',
    'subject gi'                      => 'sgi',
    'subject gis'                     => 'sallgi',
    'subject acc.'                    => 'sacc',           #from 2.5.0+
    'subject acc.ver'                 => 'saccver',        #from 2.6.0+
    'subject accs.'                   => 'sallacc',
    'subject length'                  => 'slen',
    'q. start'                        => 'qstart',         #yes
    'q. end'                          => 'qend',           #yes
    's. start'                        => 'sstart',         #yes
    's. end'                          => 'send',           #yes
    'query seq'                       => 'qseq',
    'subject seq'                     => 'sseq',
    'evalue'                          => 'evalue',         #yes
    'bit score'                       => 'bitscore',       #yes
    'score'                           => 'score',
    'alignment length'                => 'length',         #yes
    '% identity'                      => 'pident',         #yes
    'identical'                       => 'nident',
    'mismatches'                      => 'mismatch',       #yes
    'positives'                       => 'positive',
    'gap opens'                       => 'gapopen',        #yes
    'gaps'                            => 'gaps',
    '% positives'                     => 'ppos',
    'query/sbjct frames'              => 'frames',
    'query frame'                     => 'qframe',
    'sbjct frame'                     => 'sframe',
    'BTOP'                            => 'btop',
    'subject tax id'                  => 'staxid',         #from 2.4.0+
    'subject sci name'                => 'ssciname',       #from 2.4.0+
    'subject com names'               => 'scomname',       #from 2.4.0+
    'subject blast name'              => 'sblastname',     #from 2.4.0+
    'subject super kingdom'           => 'sskingdom',      #from 2.4.0+
    'subject tax ids'                 => 'staxids',
    'subject sci names'               => 'sscinames',
    'subject com names'               => 'scomnames',  #blast: header reused
    'subject blast names'             => 'sblastnames',
    'subject super kingdoms'          => 'sskingdoms',
    'subject title'                   => 'stitle',
    'subject titles'                  => 'salltitles',
    'subject strand'                  => 'sstrand',
    '% subject coverage'              => 'qcovs',
    '% hsp coverage'                  => 'qcovhsp',
    'query coverage per uniq subject' => 'qcovus',         #from 2.3.0+
};

my $MAP_RANK = {
    'sseqid'      => 'id',    #upto 2.4.0+
    'sacc'        => 'id',    #from 2.5.0+
    'saccver'     => 'id',    #from 2.6.0+
    'evalue'      => 'expect',
    'bitscore'    => 'bits',
    'stitle'      => 'summary',
    'salltitles'  => 'summary',
};

my $MAP_SUM = {
    'sseqid'      => 'id',    #upto 2.4.0+
    'sacc'        => 'id',    #from 2.5.0+
    'saccver'     => 'id',    #from 2.6.0+
    'length'      => 'length',
    'stitle'      => 'desc',
    'salltitles'  => 'desc',
};

my $MAP_ALN = {
    'evalue'      => 'expect',
    'bitscore'    => 'bits',
    'qseq'        => 'query',
    'qstart'      => 'query_start',
    'qend'        => 'query_stop',
    'sseq'        => 'sbjct',
    'sstart'      => 'sbjct_start',
    'send'        => 'sbjct_stop',
    'pident'      => 'id_percent',
};

my $MAP_EXTRA = {
    'staxid'      => 1,
    'ssciname'    => 1,
    'scomname'    => 1,
    'sblastname'  => 1,
    'sskingdom'   => 1,
    'staxids'     => 1,
    'sscinames'   => 1,
    'scomnames'   => 1,
    'sblastnames' => 1,
    'sskingdoms'  => 1,
};

#Given a string in 'line' of tab-separated fields named as in 'blastopts',
#extract those in 'wanted' storing each such key/value into 'hash'; returns
#number of fields read or -1 on error.
sub get_fields {
    my ($line, $blastopts, $wanted, $hash, $debug) = (@_, 0);
    my @list = split("\t", $line);
    if ($debug) {
        #warn "GF: [@$blastopts] => [@{[keys %$wanted]}] => [@{[values %$wanted]}]\n";
        #warn "GF: [$line]\n";
    }
    return -1  if scalar @list != scalar @$blastopts;
    my $c = 0;
    my @extra = ();
    foreach my $blastopt (@$blastopts) {
        my $val = shift @list;
        $val =~ s/^\s+|\s+$//g;  #strip trailing pipes

        #warn "$blastopt\n";
        if (exists $wanted->{$blastopt}) {

            my $mview_attr = $wanted->{$blastopt};

            #create or update key/value
            if (exists $hash->{$mview_attr} and
                length($val) > length($hash->{$mview_attr})) {
                $hash->{$mview_attr} = $val;
                warn "GF(update): [$blastopt] => [$mview_attr] => [$val]\n"  if $debug;
            } else {
                $hash->{$mview_attr} = $val;
                warn "GF(new):    [$blastopt] => [$mview_attr] => [$val]\n"  if $debug;
            }
            $c++;  #count required fields
        } elsif (exists $MAP_EXTRA->{$blastopt}) {
            #warn "save extra: $blastopt\n";
            push @extra, "$blastopt\001$val";
        }
    }
    $hash->{'extra'} = join("\000", @extra)  if @extra;
    #warn "GF: read $c fields\n"  if $debug;
    return $c;
}

#strip leading identifier from summary string
sub strip_id {
    my ($id, $s) = @_;
    if (my $c = index($s, $id) == 0) {
        $s = substr($s, length($id));
    }
    $s =~ s/^\s+|\s+$//g;
    $s;
}

sub new {
    my $type = shift;
    if (@_ < 2) {
	#at least two args, ($offset, $bytes are optional).
	Bio::Message::die($type, "new() invalid arguments (@_)");
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Record_Stream($self);

    while (defined ($line = $text->next_line)) {

	#blank line or empty record: ignore
	next  if $line =~ /$NULL/o;

	#HEADER block
	if ($line =~ /$HEADER_START/o) {
	    $text->scan_until($HEADER_END, 'HEADER');
	    next;
	}

	#SEARCH block
	if ($line =~ /$SEARCH_START/o) {
	    $text->scan_until($SEARCH_END, 'SEARCH');
	    next;
	}

        #stop at psiblast convergence message
        last  if $line =~ /^Search has CONVERGED/;

        #stop before terminal comment
        last  if $line =~ /$ENTRY_END/;

	#default
	$self->warn("unknown field: $line");
    }

    $self;#->examine;
}


###########################################################################
package Bio::Parse::Format::BLAST2_OF7::HEADER;

use vars qw(@ISA);

@ISA = qw(Bio::Parse::Record);

sub new {
    my $type = shift;
    if (@_ < 2) {
	#at least two args, ($offset, $bytes are optional).
	Bio::Message::die($type, "new() invalid arguments (@_)");
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Record_Stream($self);

    #BLAST
    $self->{'full_version'} = '';
    $self->{'version'}      = '';
    $self->{'query'}        = '';
    $self->{'summary'}      = '';

    #BLAST2_OF7
    $self->{'fields'}       = [];

    while ($line = $text->next_line(1)) {

	#blast version info
	if ($line =~ /^# ($PROGRAMS\s+(\S+))/o) {
	    $self->test_args(\$line, $1, $2);
	    (
	     $self->{'full_version'},
	     $self->{'version'},
	    ) = ($1, $2);
	    next;
	}

        if ($line =~ /^# Query:\s+(.*)/o) {
            $self->{'query'} = $1;
            $self->{'summary'} = '';  #never set
            next;
        }

        if ($line =~ /^# Fields:\s+(.*)/o) {
            $self->save_field_list($1);
            $self->extract_fields;
            next;
        }

        next  if $line =~ /^# Iteration:\s+(\d+)/o;
        next  if $line =~ /^# Database:/o;
        next  if $line =~ /^# \d+ hits found/o;

	#default
	$self->warn("unknown field: $line");
    }
    $self;
}

sub save_field_list {
    my $self = shift;
    my $out = [];
    my @extra = ();
    foreach my $f (split(/,\s+/, $_[0])) {
        if (exists $FIELD_MAP->{$f}) {
            my $blastopt = $FIELD_MAP->{$f};
            push @$out, $blastopt;
        } else {
            push @$out, $FIELD_SKIP;
        }
    }
    $self->{'fields'} = $out;
}

sub extract_fields {
    my $self = shift;
    my @extra = ();
    foreach my $blastopt (@{$self->{'fields'}}) {
        push @extra, "$blastopt\001"  if exists $MAP_EXTRA->{$blastopt};
    }
    $self->{'extra'}  = join("\000", @extra)  if @extra;
}

sub print_data {
    my ($self, $indent) = (@_, 0);
    my $x = ' ' x $indent;
    printf "$x%20s -> %s\n", 'version',      $self->{'version'};
    printf "$x%20s -> %s\n", 'full_version', $self->{'full_version'};
    printf "$x%20s -> %s\n", 'query',        $self->{'query'};
    printf "$x%20s -> %s\n", 'summary',      $self->{'summary'};
    printf "$x%20s -> %s\n", 'fields',       "@{$self->{'fields'}}";
}


###########################################################################
package Bio::Parse::Format::BLAST2_OF7::SEARCH;

use vars qw(@ISA);

@ISA = qw(Bio::Parse::Format::BLAST2::SEARCH);

sub new {
    my $type = shift;
    if (@_ < 2) {
        #at least two args, ($offset, $bytes are optional).
        Bio::Message::die($type, "new() invalid arguments (@_)");
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Record_Stream($self);

    #create SEARCH::RANK
    $self->push_record('RANK', $offset, $bytes);

    $self;#->examine;
}


###########################################################################
package Bio::Parse::Format::BLAST2_OF7::SEARCH::RANK;

use vars qw(@ISA);

@ISA = qw(Bio::Parse::Format::BLAST::RANK);

sub new {
    my $type = shift;
    if (@_ < 2) {
	#at least two args, ($offset, $bytes are optional).
	Bio::Message::die($type, "new() invalid argument list (@_)");
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);
    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Record_Stream($self);

    #column headers
    $self->{'header'} = '';

    #ranked search hits
    $self->{'hit'}    = [];

    #fetch fields
    my $fields = $self->get_parent(2)->get_record('HEADER')->{'fields'};
    #warn "[@{[scalar @$fields]}] [@{$fields}]\n";

    #accumulate text block data for same hit id on successive lines
    my ($mid, $moffset, $mbytes) = ('', 0, 0);

    while (defined ($line = $text->next_line(1))) {
        #warn "[$line]\n";

        my $tmp = {};

        if ($line =~ /$SEARCH_START/o) {

            #BLAST2
            $tmp->{'id'}      = '';
            $tmp->{'bits'}    = '';
            $tmp->{'expect'}  = '';
            $tmp->{'n'}       = '0';  #default
            $tmp->{'summary'} = '';

            #extract relevant fields
            my $c = Bio::Parse::Format::BLAST2_OF7::get_fields($line,
                                                               $fields,
                                                               $MAP_RANK,
                                                               $tmp);

            if ($c < 0) {
                $self->die("field count mismatch (expect @{[scalar @$fields]}, got $c)\n");
            }

            if ($tmp->{'id'} eq '') {
                $self->die("blast column 'sseqid/sacc' is needed to identify hits");
            }

            $tmp->{'summary'} =
                Bio::Parse::Format::BLAST2_OF7::strip_id($tmp->{'id'},
                                                         $tmp->{'summary'});
            $tmp->{'id'} = Bio::Parse::Record::clean_identifier($tmp->{'id'});

            #id same as last line: extend SEARCH::MATCH block
            if ($mid eq $tmp->{'id'}) {
                $parent->pop_record;
                $parent->push_record('MATCH', $moffset,
                                     $mbytes += $text->get_bytes);
                #expect the first hit supplied by blast to be the highest
                #scoring, but test just in case:
                if ($tmp->{'bits'} > $self->{'hit'}->[-1]->{'bits'}) {
                    #warn "later hit has greater bits score\n";
                    pop  @{$self->{'hit'}};
                    push @{$self->{'hit'}}, $tmp;
                }
                next;
            }

            #new id: create SEARCH::MATCH
            ($mid, $moffset, $mbytes) = ($tmp->{'id'}, $text->get_offset,
                                         $text->get_bytes);
            $parent->push_record('MATCH', $moffset, $mbytes);

            push @{$self->{'hit'}}, $tmp;

            next;
        }

	#blank line or empty record: ignore
	next  if $line =~ /$NULL/o;

        #psiblast convergence message: ignore
        next  if $line =~ /^Search has CONVERGED/o;

	#default
	$self->warn("unknown field: $line");
    }

    $self;#->examine;
}

sub print_data {
    my ($self, $indent) = (@_, 0);
    my $x = ' ' x $indent;
    printf "$x%20s -> '%s'\n", 'header', $self->{'header'};
    foreach my $hit (@{$self->{'hit'}}) {
	foreach my $field (sort keys %$hit) {
            my $s = $hit->{$field};
            $s =~ s/\000/,/g;
            $s =~ s/\001/:/g;
            printf "$x%20s -> %s\n", $field, $s;
	}
    }
}


###########################################################################
package Bio::Parse::Format::BLAST2_OF7::SEARCH::MATCH;

use vars qw(@ISA);

@ISA = qw(Bio::Parse::Format::BLAST::MATCH);

sub new {
    my $type = shift;
    if (@_ < 2) {
	#at least two args, ($offset, $bytes are optional).
	Bio::Message::die($type, "new() invalid argument list (@_)");
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Record_Stream($self);

    #create SEARCH::MATCH::SUM
    $self->push_record('SUM', $offset, $bytes);

    while (defined ($line = $text->next_line(1))) {
        #warn "[$line]\n";

        if ($line =~ /$SEARCH_START/o) {
            #create SEARCH::MATCH::ALN
            $self->push_record('ALN', $text->get_offset, $text->get_bytes);
            next;
        }

	#default
	$self->warn("unknown field: $line");
    }

    $self;#->examine;
}


###########################################################################
package Bio::Parse::Format::BLAST2_OF7::SEARCH::MATCH::SUM;

use vars qw(@ISA);

@ISA = qw(Bio::Parse::Format::BLAST2::SEARCH::MATCH::SUM);

sub new {
    my $type = shift;
    if (@_ < 2) {
	#at least two args, ($offset, $bytes are optional).
	Bio::Message::die($type, "new() invalid argument list (@_)");
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Record_Stream($self);

    #BLAST
    $self->{'id'}     = '';
    $self->{'desc'}   = '';
    $self->{'length'} = '';

    $self->extract_fields($MAP_SUM, $text->next_line(1));

    $self->{'desc'} =
        Bio::Parse::Format::BLAST2_OF7::strip_id($self->{'id'},
                                                 $self->{'desc'});
    $self->{'id'} = Bio::Parse::Record::clean_identifier($self->{'id'});

    $self;#->examine;
}

sub extract_fields {
    my ($self, $map, $line) = @_;
    my $fields = $self->get_parent(3)->get_record('HEADER')->{'fields'};
    Bio::Parse::Format::BLAST2_OF7::get_fields($line, $fields, $map, $self);
}


###########################################################################
package Bio::Parse::Format::BLAST2_OF7::SEARCH::MATCH::ALN;

use vars qw(@ISA);

@ISA = qw(Bio::Parse::Format::BLAST2::SEARCH::MATCH::ALN);

sub new {
    my $type = shift;
    if (@_ < 2) {
	#at least two args, ($offset, $bytes are optional).
	Bio::Message::die($type, "new() invalid argument list (@_)");
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new Bio::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new Bio::Parse::Record_Stream($self);

    #BLAST
    $self->{'query'}        = '';
    $self->{'align'}        = '';
    $self->{'sbjct'}        = '';
    $self->{'query_orient'} = '';
    $self->{'query_start'}  = '';
    $self->{'query_stop'}   = '';
    $self->{'sbjct_orient'} = '';
    $self->{'sbjct_start'}  = '';
    $self->{'sbjct_stop'}   = '';

    #BLAST2
    $self->{'bits'}         = '';
    $self->{'score'}        = '';
    $self->{'n'}            = '1';  #default
    $self->{'expect'}       = '';
    $self->{'id_fraction'}  = '';
    $self->{'id_percent'}   = '';
    $self->{'pos_fraction'} = '';
    $self->{'pos_percent'}  = '';
    $self->{'gap_fraction'} = '';
    $self->{'gap_percent'}  = '';

    $self->extract_fields($MAP_ALN, $text->next_line(1));

    #use sequence numbering to get orientations
    $self->{'query_orient'} =
        $self->{'query_start'} > $self->{'query_stop'} ? '-' : '+';
    $self->{'sbjct_orient'} =
        $self->{'sbjct_start'} > $self->{'sbjct_stop'} ? '-' : '+';

    $self;#->examine;
}

sub extract_fields {
    my ($self, $map, $line) = @_;
    my $fields = $self->get_parent(3)->get_record('HEADER')->{'fields'};
    Bio::Parse::Format::BLAST2_OF7::get_fields($line, $fields, $map, $self);
}


###########################################################################
1;