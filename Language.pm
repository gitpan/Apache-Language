#$Id: Language.pm,v 1.4 1999/02/04 03:34:06 gozer Exp $
package Apache::Language;

use strict;
use vars qw(%CACHE $VERSION %USAGE);
use IO::File;

$VERSION = '0.01';

if ($ENV{'MOD_PERL'} && Apache->module('Apache::Status')) {
		Apache::Status->menu_item('Language' => 'Apache::Language status', \&status);
		}

sub new {
	my ($class, $r) = @_;
	my ($package, $filename, $line) = caller;
	if ($CACHE{$package}){
		#should contain more validity check on the cached data
		}
	else 	{
		#Populate new object with useful information
		my $self =	{
				Filename	=> $filename,
				Package		=> $package
				};
		$filename =~ s/\.pm$/.dic/;		#Find the language file
		if ($package =~ /^Apache::ROOT/)
			{
			#This is under Apache::Registry, so simply append .dic to the script name
			$filename =~ s/^(.*)$/$1.dic/;
			}
	
		local($/) = "";		#read untill empty line
		my $fh = IO::File->new;
		$fh->open($filename) or warn "NO Language definitions found";
		
		while (<$fh>){
			#this should be more carefully validating stuff..
			my ($lang, $code) = /([^:]*):(\w+)/ or last;
			die "Bad syntax : $_" unless $code;
			
			#set default language to be the first one encountered
			$self->{default_language} = $lang unless exists $self->{default_language};
			
			$USAGE{$lang} = 0 unless $USAGE{$lang};	#Initialize statistics data
			
			my $string = <$fh> if defined($fh) or "No string found";
			$self->{DATA}{$lang}{$code} = $string;
			}	
		$fh->close;
		
		bless $self, $class;
		$CACHE{$package} = $self;	#store newly created object for future use
	}
	#now what language is requested ?
	my $lang = $CACHE{$package}->find_lang($r);
	
	#and remember it for the life of this specific object.
	$CACHE{$package}{lang} = $lang;
	return $CACHE{$package};
	}

sub message{
	#this should be more optimal, in the case it's not called with arguments
	my ($self, $message, @args) = @_;
	$USAGE{$self->{lang}}++;	#Gather statistics.
	sprintf $self->{DATA}{$self->{lang}}{$message}, @args;
	}

sub find_lang {
	#What language this request should be served with ?
	my ($self, $r) = @_;
	#Is one specific language forced ?
	return $r->dir_config("Language") if ($r->dir_config("Language"));
	my $value = 1;	
	my %pairs = {};
	
	foreach (split(/,/, $r->header_in("Accept-Language"))){
		s/\s//g;	#strip spaces
		if (m/;q=([\d\.]+)/){	
			#is it in the "en;q=0.4" form ?
			$pairs{$`}=$1 if $1 > 0;
			}
		else	{
			#give the first one a q of 1
			$pairs{$_} = $value;
			#and the others .001 less every time
			$value -= 0.001;
			}
		}
	
	my $choice;	#what will it be ?
	
	foreach (sort {$pairs{$b} <=> $pairs{$a}} keys %pairs) {
		#try keys in order of preference
		if (exists $self->{DATA}{$_})
			{
			$choice = $_;
			last;
			}
		}
	#did we find something ?
	if (!$choice) {
		#guess not, must use the defaults then.
		$choice = $r->dir_config("DefaultLanguage") || $self->{default_language} || 'en';
		warn "Defaulting to $choice";
		}	
	
return $choice;			
}

sub status {
	#Produce nice information if Apache::Status is enabled
	my ($r, $q) = @_;
	my @s;
	
	push (@s, "<B>" , __PACKAGE__ , " (ver $VERSION) statistics</B><BR>");
	
	push (@s, "Languages requested:<BR>");
	push (@s, "<OL>");
	#list each languaged served in order of popularity
	foreach my $lang ( sort {$USAGE{$b} <=> $USAGE{$a}} keys %USAGE){
		push (@s, "<LI>" . $lang . ", " . $USAGE{$lang} . " times.</LI>\n");
		}
	push (@s, "</OL>");
	
	#then list each module that has a language definition
	push (@s, "<UL>");
	foreach my $module( sort keys %CACHE) {
		my $uri = $r->uri;
		my $name = $module;
		if ($name =~ /^Apache::ROOT/)
			{
			#print the nicer filename instead of the module name
			$name = $CACHE{$module}{Filename};
			}	
		push (@s, "<LI><A HREF=\"$uri?$module\">" . $name . "</A></LI>");
		push (@s, "<UL>");
		foreach my $lang( sort keys %{$CACHE{$module}{DATA}}){
			#then list the known languages
			push (@s, "<LI>" . $lang . "</LI>");
			push (@s , "<UL>");
			foreach my $value (sort keys %{$CACHE{$module}{DATA}{$lang}}){
				#and each string it knows about
				push (@s, "<LI>" . $value . "</LI>");
				}
			push (@s , "</UL>");
			}
		push (@s, "</UL>");
		}
	push (@s, "</UL>");
	
	#smile!
	return \@s;
	}

1;
__END__

=head1 NAME

Apache::Language - Perl transparent language support for mod_perl scripts and Apache modules

=head1 SYNOPSIS

  In YourModule.pm:
  
  sub handler {
  my $r = shift;
  use Apache::Language;
  my $lang = new Apache::Language ($r);
  print $lang->message('Error01');
  ...
  }

  Then in YourModule.dic:
  
   en:Error01
   
   This is a bad thing you did!
   
   fr:Error01
   
   Vous venez de faire quelque chose de mauvais!
   
   de:Error01
   
   Fehler!
   

=head1 DESCRIPTION

The goal of this module is to provide a simple way for mod_perl module writers
to include support for multiple language requests.

It uses the Accept-Language: field sent by the web-client, to pick the best
fit language for it.  It's usage is almost transparent and should prove to be
quite convenient (and hopefully, efficient).

First, to use it you need to create a Apache::Language object you'll use for
the lifetime of your script, whenever you need to print information that might
be presented in different languages.

 my $r = shift
 my $lang = new Apache::Language ($r)

The first time you call that method, a specific language definitions file is
parsed and language-key-content pairs are generated.  That will be done only
once per child httpd process.

After that it's only a matter of calling the message method like so:

 print $lang->message('key');

That will produce the content for the key 'key' in the best fit language for
the current request being served. That's it.

Of course you need to set-up the dictionnary file for this to work.  If you are
writing a module, simply name the file YourModule.dic and place it in the same
place your module gets installed.  If it's a Apache::Registry script, simply add
a .dic to the script filename and place it in the same place.  Make sure the
webserver userid has read permission on the file.

The format of those Dictionnary files is pretty straight-forward

 language:key

 content

 language:key

 content

 ....

Just make sure those empty lines are B<actually> empty. You should make this list
balanced, all keys should be translated in the same languages.  If not, sometimes
Apache::Language might not be able to find a content fitting the request at all.

The message request is nothing more than a call to printf, this means you can pass
it arguments and format your content anyway you want. i.e.

 en:Error01

 You tried to %s me and I don't think you should do %s.

then call message like so:
 
 $lang->message("Error01", "kill", "such an evil thing");
 
Simple, and not as efficient as it could be, I know. :-(

Anyway, this is a first attempt at building something usefull, 
easy and efficient (or fast).  Feedback B<very> welcome.

=head1 TODO

Currently, the language file is only loaded once per child, then
cached forever after.  Last modification time should be checked
so a Dictionnary file modifications would reflect instantly. 

I think this could be more convenient to implement it as a tied
hash, that way one module could populate a given hash with defaults
values in the case that Apache::Language isn't avaliable.  This with
no more modification to the code than that.

=head1 SEE ALSO

perl(1), L<Apache>(3).

=head1 SUPPORT

Please send any questions or comments to the Apache modperl 
mailing list <modperl@apache.org> or to me at <gozer@ectoplasm.dyndns.com>

=head1 NOTES

This code was made possible by :

=over

=item *

Doug MacEachern <dougm@pobox.com>  Creator of mod_perl.  That should mean enough.

=item *

Andreas Koenig <koenig@kulturbox.de> The one I got the idea from in the first place.

=item *

The mod_perl mailing-list at <modperl@apache.org> for all your mod_perl related problems.

=back

=head1 AUTHOR

Philippe M. Chiasson <gozer@ectoplasm.dyndns.com>

=head1 COPYRIGHT

Copyright (c) 1999 Philippe M. Chiasson. All rights reserved. This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself. 

=cut
