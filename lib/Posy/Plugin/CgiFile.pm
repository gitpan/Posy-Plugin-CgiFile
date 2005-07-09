package Posy::Plugin::CgiFile;
use strict;

=head1 NAME

Posy::Plugin::CgiFile - Posy plugin to enable drop-in use of CGI scripts inside Posy.

=head1 VERSION

This describes version B<0.01> of Posy::Plugin::CgiFile.

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    @plugins = qw(Posy::Core
		  ...
		  Posy::Plugin::CgiFile
		  ...);
    %file_extensions = (
	txt=>'text',
	html=>'html',
	...
	cgi=>'cgi',
    );

=head1 DESCRIPTION

This plugin adds another file type to Posy, the 'cgi' type, which
enables normal CGI scripts to be called from within Posy, and their
output then treated as if it was entry data, with the usual flavour
templating done on top of that.

This expects the file_extensions to have been set so that files
with appropriate extensions ('cgi') will have been set with
a file-type of 'cgi'.

This replaces the 'parse_entry' method, and calls the parent
method for anything other than CGI.

This also replaces the 'get_title' method used by
Posy::Plugin::EntryTitles, so if one is using that module, one needs to
put this after that in the plugin list.

=head2 Cautions

This plugin may not work if it is not run on a Unix-like system.
This plugin may not work if the given CGI script has too complicated
a setup.

This plugin may not work if the CGI script gets confused between its own
parameters and the parameters used by Posy and/or other Posy plugins
which are also being used.

This plugin will not work with scripts which require the use of
the PATH_INFO or PATH_TRANSLATED environment variables.

=head2 Activation

This plugin needs to be added to the plugins list and the
file_extensions hash.

This overrides the 'parse_entry' and 'get_title' methods; therefore care
needs to be taken with other plugins if they override the same methods.

Note that the URL used to call the dropped-in script is not going to be
'script.cgi', but should use the usual Posy flavour extensions;
thus, it would be called as 'script.html?myparam=myvalue' for example.

=cut

=head1 Entry Action Methods

Methods implementing per-entry actions.

=head2 parse_entry

$self->parse_entry($flow_state, $current_entry, $entry_state)

Parses $current_entry->{raw} into $current_entry->{title}
and $current_entry->{body}

=cut
sub parse_entry {
    my $self = shift;
    my $flow_state = shift;
    my $current_entry = shift;
    my $entry_state = shift;

    my $id = $current_entry->{id};
    my $file_type = $self->{file_extensions}->{$self->{files}->{$id}->{ext}};
    if ($file_type eq 'cgi')
    {
	$self->debug(2, "$id is cgi");
	my $result = '';
	# call the CGI script
	# do a fork and exec with an open;
	# this should preserve the environment and also be safe
	my $pid = open(KID_TO_READ, "-|");
	if ($pid) # parent
	{
	    while(<KID_TO_READ>) {
		$result .= $_;
	    }
	    close(KID_TO_READ) || warn "$id CGI script exited $?";
	}
	else # child
	{
	    # figure out the working directory of the CGI script
	    $self->{path}->{cat_id} =~ m#([-_.\/\w]+)#;
	    my $path = $1; # untaint
	    $path = '' if (!$self->{path}->{cat_id});
	    my $fulldir = File::Spec->catdir($self->{data_dir}, $path);
	    chdir $fulldir;
	    # clear the PATH_INFO and PATH_TRANSLATED
	    my $path_info = $self->{path}->{info};
	    my $fullpath = File::Spec->catdir($self->{data_dir}, $path_info);
	    delete $ENV{PATH_INFO};
	    delete $ENV{PATH_TRANSLATED};
	    $ENV{SCRIPT_NAME} = $self->{url} . '/' . $self->{path}->{cat_id} . '/' . $self->{path}->{basename} . "." . $self->{files}->{$id}->{ext};
	    $ENV{SCRIPT_FILENAME} = File::Spec->catfile($fulldir,  $self->{path}->{basename} . "." . $self->{files}->{$id}->{ext});

	    my $script = $self->{files}->{$id}->{fullname};
	    exec($script)
		|| die "can't exec $id: $!";
	    # NOTREACHED
	}

	$result =~ m#<head>(.*)</head>#si;
	$current_entry->{html_head} = $1;
	$current_entry->{html_head} =~ s#<title>(.*)</title>##si;
	$result =~ m#<title>(.*)</title>#si;
	$current_entry->{title} = $1;
	$result =~ m#<body([^>]*)>(.*)</body>#is;
	$current_entry->{body_attrib} = $1;
	$current_entry->{body} = $2;
    }
    else # use parent
    {
	$self->SUPER::parse_entry($flow_state, $current_entry, $entry_state);
    }
    1;
} # parse_entry

=head1 Helper Methods

Methods which can be called from elsewhere.

=head2 get_title

    $title = $self->get_title($file_id);

Get the title of the given entry file (by reading the file).

=cut
sub get_title {
    my $self = shift;
    my $file_id = shift;

    my $fullname = $self->{files}->{$file_id}->{fullname};
    my $ext = $self->{files}->{$file_id}->{ext};
    my $file_type = $self->{file_extensions}->{$ext};
    my $title = '';
    my $fh;
    if ($file_type eq 'pod')
    {
	# just give it the simple basename
	$title = $self->{files}->{$file_id}->{basename};
    }
    else # use parent
    {
	$title = $self->SUPER::get_title($file_id);
    }
    return $title;
} # get_title

=head1 Private Methods


=head1 INSTALLATION

Installation needs will vary depending on the particular setup a person
has.

=head2 Administrator, Automatic

If you are the administrator of the system, then the dead simple method of
installing the modules is to use the CPAN or CPANPLUS system.

    cpanp -i Posy::Plugin::CgiFile

This will install this plugin in the usual places where modules get
installed when one is using CPAN(PLUS).

=head2 Administrator, By Hand

If you are the administrator of the system, but don't wish to use the
CPAN(PLUS) method, then this is for you.  Take the *.tar.gz file
and untar it in a suitable directory.

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't like the
"./" notation, you can do this:

   perl Build.PL
   perl Build
   perl Build test
   perl Build install

=head2 User With Shell Access

If you are a user on a system, and don't have root/administrator access,
you need to install Posy somewhere other than the default place (since you
don't have access to it).  However, if you have shell access to the system,
then you can install it in your home directory.

Say your home directory is "/home/fred", and you want to install the
modules into a subdirectory called "perl".

Download the *.tar.gz file and untar it in a suitable directory.

    perl Build.PL --install_base /home/fred/perl
    ./Build
    ./Build test
    ./Build install

This will install the files underneath /home/fred/perl.

You will then need to make sure that you alter the PERL5LIB variable to
find the modules.

Therefore you will need to change the PERL5LIB variable to add
/home/fred/perl/lib

	PERL5LIB=/home/fred/perl/lib:${PERL5LIB}

=head1 REQUIRES

    Test::More

=head1 SEE ALSO

perl(1).
Posy

=head1 BUGS

Please report any bugs or feature requests to the author.

=head1 AUTHOR

    Kathryn Andersen (RUBYKAT)
    perlkat AT katspace dot com
    http://www.katspace.com

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2005 by Kathryn Andersen

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Posy::Plugin::CgiFile
__END__
