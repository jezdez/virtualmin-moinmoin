# Copyright (c) 2008, Jannis Leidel
# All rights reserved.
#
# Changelog
# 
# 0.1 - initial release

# script_moinmoin_desc()
sub script_moinmoin_desc
{
return "MoinMoin";
}

sub script_moinmoin_uses
{
return ( "python" );
}

sub script_moinmoin_longdesc
{
return "Advanced, easy to use and extensible WikiEngine with a large community of users.";
}

# script_moinmoin_versions()
sub script_moinmoin_versions
{
return ( "1.6.3" );
}

sub script_moinmoin_python_modules
{
local ($d, $ver, $opts) = @_;
return ( "setuptools", "xml", "docutils" );
}

# script_moinmoin_depends(&domain, version)
# Check for ruby command, ruby gems, mod_proxy
sub script_moinmoin_depends
{
local ($d, $ver) = @_;
&has_command("python") || return "The python command is not installed";
&require_apache();
local $conf = &apache::get_config();
$apache::httpd_modules{'mod_fcgid'} ||
	return "Apache does not have the mod_fcgid module";
return undef;
}

# script_moinmoin_params(&domain, version, &upgrade-info)
# Returns HTML for table rows for options for installing PHP-NUKE
sub script_moinmoin_params
{
local ($d, $ver, $upgrade) = @_;
local $rv;
local $hdir = &public_html_dir($d, 1);
if ($upgrade) {
	# Options are fixed when upgrading
	$rv .= &ui_table_row("Wiki name", $upgrade->{'opts'}->{'wikiname'});
	$rv .= &ui_table_row("Admin name", $upgrade->{'opts'}->{'adminname'});
	local $dir = $upgrade->{'opts'}->{'dir'};
	$dir =~ s/^$d->{'home'}\///;
	$rv .= &ui_table_row("Install directory", $dir);
	}
else {
	# Show editable install options
	$rv .= &ui_table_row("Wiki name (e.g. MyWiki)",
			 &ui_textbox("wikiname", "", 30));
	$rv .= &ui_table_row("Admin name (e.g. FirstnameLastname)",
			 &ui_textbox("adminname", "", 30));
	$rv .= &ui_table_row("Install sub-directory under <tt>$hdir</tt>",
				 &ui_opt_textbox("dir", undef, 30,
						 "At top level"));
	}
return $rv;
}

# script_moinmoin_parse(&domain, version, &in, &upgrade-info)
# Returns either a hash ref of parsed options, or an error string
sub script_moinmoin_parse
{
local ($d, $ver, $in, $upgrade) = @_;
if ($upgrade) {
	# Options are always the same
	return $upgrade->{'opts'};
	}
else {
	local $hdir = &public_html_dir($d, 0);
	$in->{'dir_def'} || $in->{'dir'} =~ /\S/ && $in->{'dir'} !~ /\.\./ ||
		return "Missing or invalid installation directory";
	local $dir = $in->{'dir_def'} ? $hdir : "$hdir/$in->{'dir'}";
	$in{'wikiname'} =~ /^[A-Za-z]+$/ ||
		return "Wiki name can only contain letters";
	$in{'adminname'} =~ /^[A-Z][a-z]+[A-Z]\w+$/ ||
		return "Admin name must be in CamelCase";
	return { 'dir' => $dir,
		 'path' => $in->{'dir_def'} ? "/" : "/$in->{'dir'}",
		 'wikiname' => $in{'wikiname'},
		 'adminname' => $in{'adminname'} };
	}
}

# script_moinmoin_check(&domain, version, &opts, &upgrade-info)
# Returns an error message if a required option is missing or invalid
sub script_moinmoin_check
{
local ($d, $ver, $opts, $upgrade) = @_;
$opts->{'dir'} =~ /^\// || return "Missing or invalid install directory";
if (-r "$opts->{'dir'}/moin.fcg") {
	return "MoinMoin appears to be already installed in the selected directory";
	}
$opts->{'wikiname'} || return "Missing Wiki name";
$opts->{'wikiname'} =~ /^[A-Za-z]+$/ ||
	return "Wiki name can only contain letters";
$opts->{'adminname'} || return "Missing admin name";
$opts->{'adminname'} =~ /^[A-Z][a-z]+[A-Z]\w+$/ ||
	return "Admin name must be in CamelCase";
return undef;
}

# script_moinmoin_files(&domain, version, &opts, &upgrade-info)
# Returns a list of files needed by Rails, each of which is a hash ref
# containing a name, filename and URL
sub script_moinmoin_files
{
local ($d, $ver, $opts, $upgrade) = @_;
local @files = (
	 { 'name' => "source",
	   'file' => "moin-$ver.tar.gz",
	   'url' => "http://static.moinmo.in/files/moin-$ver.tar.gz" },
	);
return @files;
}

sub script_moinmoin_commands
{
local ($d, $ver, $opts) = @_;
return ("python");
}

# script_moinmoin_install(&domain, version, &opts, &files, &upgrade-info)
# Actually installs PhpWiki, and returns either 1 and an informational
# message, or 0 and an error
sub script_moinmoin_install
{
local ($d, $version, $opts, $files, $upgrade) = @_;
local ($out, $ex);
local $python = &has_command("python");

# Create target dir
if (!-d $opts->{'dir'}) {
	$out = &run_as_domain_user($d, "mkdir -p ".quotemeta($opts->{'dir'}));
	-d $opts->{'dir'} ||
		return (0, "Failed to create directory : <tt>$out</tt>.");
	}

# Create python base dir
$ENV{'PYTHONPATH'} = "$opts->{'dir'}/lib/python";
&run_as_domain_user($d, "mkdir -p ".quotemeta($ENV{'PYTHONPATH'}));

# Extract the source, then install to the target dir
local $temp = &transname();
local $err = &extract_script_archive($files->{'source'}, $temp, $d);
$err && return (0, "Failed to extract MoinMoin source : $err");
local $icmd = "cd ".quotemeta("$temp/moin-$ver")." && ".
	  "python setup.py install --home ".quotemeta($opts->{'dir'})." 2>&1";
local $out = &run_as_domain_user($d, $icmd);
if ($?) {
	return (0, "MoinMoin install failed : ".
		   "<pre>".&html_escape($out)."</pre>");
	}
if (!$upgrade) {
	local $share = $opts->{'dir'}."/share/moin";
	local $wikiconfig = $share."/config/wikiconfig.py";
	local $wikidir = "$opts->{'dir'}/$opts->{'wikiname'}";
	local $icmd = "cd ".quotemeta($opts->{'dir'})." && ".
		  "mkdir -p ".quotemeta($wikidir)." && ".
		  "cp -R ".$share."/data ".$wikidir." && ".
		  "cp -R ".$share."/underlay ".$wikidir." && ".
		  "cp ".$wikiconfig." ".$wikidir." && 2>&1";
	local $out = &run_as_domain_user($d, $icmd);
	if ($?) {
		return (0, "Wiki initialization failed : ".
			   "<pre>".&html_escape($out)."</pre>");
		}
	# Fix wikiconfig.py
	local $url = &script_path_url($d, $opts);
	local $sfile = "$wikidir/wikiconfig.py";
	-r $sfile || return (0, "Wiki config file $sfile was not found");
	local $lref = &read_file_lines($sfile);
	my $i = 0;
	foreach my $l (@$lref) {
	  if ($l =~ /data_dir\s*=/) {
		  $l = "    data_dir = '$wikidir/data'";
		  }
	  if ($l =~ /data_underlay_dir\s*=/) {
		  $l = "    data_underlay_dir = '$wikidir/underlay'";
		  }
	  if ($l =~ /superuser\s*=/) {
		  $l = "    superuser = [u'$opts->{'adminname'}', ]";
		  }
	  if ($l =~ /acl_rights_before\s*=/) {
		  $l = "    acl_rights_before = u'$opts->{'adminname'}:read,write,delete,revert,admin'";
		  }
	  if ($l =~ /sitename\s*=/) {
		  $l = "    sitename = u'$opts->{'wikiname'}'";
		  }
	  if ($l =~ /url_prefix_static\s*=/) {
		  $l = "    url_prefix_static = '/moin_static'";
		  }
	  if ($l =~ /page_front_page\s*=/) {
		  $l = "    page_front_page = u'FrontPage'";
		  }
	  if ($l =~ /logo_string\s*=/) {
		  $l = "    logo_string = u'<img src=\"/moin_static/common/moinmoin.png\" alt=\"MoinMoin Logo\">'";
		  }
	  $i++;
	  }
	&flush_file_lines($sfile);

	local $wrapper = "$opts->{'dir'}/moin.fcgi";
	if (!-r $wrapper) {
		&open_tempfile(WRAPPER, ">$wrapper");
		&print_tempfile(WRAPPER, "#!$python\n");
		&print_tempfile(WRAPPER, "import sys, logging\n");
		&print_tempfile(WRAPPER, "sys.path.insert(0, '$opts->{'dir'}/lib/python')\n");
		&print_tempfile(WRAPPER, "sys.path.insert(0, '$wikidir')\n");
		&print_tempfile(WRAPPER, "from MoinMoin.server.server_fastcgi import FastCgiConfig, run\n");
		&print_tempfile(WRAPPER, "class Config(FastCgiConfig):\n");
		&print_tempfile(WRAPPER, "    logPath = '$d->{'home'}/logs/moin.log'\n");
		&print_tempfile(WRAPPER, "    properties = {}\n");
		&print_tempfile(WRAPPER, "run(Config)\n");
		&close_tempfile(WRAPPER);
		&set_ownership_permissions($d->{'uid'}, $d->{'ugid'}, 0755, $wrapper);
		}
	}

local $htdocs = $opts->{'dir'}."/share/moin/htdocs";
local $conf = &apache::get_config();
local @ports = ( $d->{'web_port'},
		 $d->{'ssl'} ? ( $d->{'web_sslport'} ) : ( ) );
foreach my $port (@ports) {
	local ($virt, $vconf) = &get_apache_virtual($d->{'dom'}, $port);
	next if (!$virt);
	local @sa = &apache::find_directive("Alias", $vconf);
	local @sam = &apache::find_directive("ScriptAliasMatch", $vconf);
	local ($robots) = grep { $_ =~ /^\/robots.txt/ } @sa;
	if (!$robots) {
		push(@sa, "/robots.txt $htdocs/robots.txt");
		&apache::save_directive("Alias", \@sa,
					$vconf, $conf);
		}
	local ($favicon) = grep { $_ =~ /^\/favicon.ico/ } @sa;
	if (!$favicon) {
		push(@sa, "/favicon.ico $htdocs/favicon.ico");
		&apache::save_directive("Alias", \@sa,
					$vconf, $conf);
		}
	local ($static) = grep { $_ =~ /^\/moin_static/ } @sa;
	if (!$static) {
		push(@sa, "/moin_static $htdocs");
		&apache::save_directive("Alias", \@sa,
					$vconf, $conf);
		}
	local ($msam) = grep { $_ =~ /^\$opts->{'path'}/ } @sam;
	if (!$msam) {
		push(@sam, "^$opts->{'path'}(.*) $opts->{'dir'}/moin.fcgi/\$1");
		&apache::save_directive("ScriptAliasMatch", \@sam,
					$vconf, $conf);
		}
	local @locs = &apache::find_directive_struct("Location", $vconf);
	local ($loc) = grep { $_->{'words'}->[0] eq $opts->{'path'} } @locs;
	next if ($loc);
	local $loc = { 'name' => 'Location',
			   'value' => $opts->{'path'},
			   'type' => 1,
			   'members' => [
			{ 'name' => 'AddHandler',
			  'value' => 'fcgid-script .fcgi' },
			{ 'name' => 'Options',
			  'value' => 'ExecCGI' },
			]
		};
	&apache::save_directive_struct(undef, $loc, $vconf, $conf);
	&flush_file_lines($virt->{'file'});
	}
&register_post_action(\&restart_apache);

local $url = &script_path_url($d, $opts);
local $rp = $opts->{'dir'};
$rp =~ s/^$d->{'home'}\///;
return (1, "Initial MoinMoin installation complete. Go to <a target=_new href='$url'>$url</a>.", $url);

}

# script_moinmoin_uninstall(&domain, version, &opts)
# Un-installs a MoinMoin installation, by deleting the directory and database.
# Returns 1 on success and a message, or 0 on failure and an error
sub script_moinmoin_uninstall
{
local ($d, $version, $opts) = @_;

# Remove the contents of the target directory
local $derr = &delete_script_install_directory($d, $opts);
return (0, $derr) if ($derr);

# Remove <Location> block, Alias and ScriptAliasMatch directives
&require_apache();
local $conf = &apache::get_config();
local @ports = ( $d->{'web_port'},
		 $d->{'ssl'} ? ( $d->{'web_sslport'} ) : ( ) );
foreach my $port (@ports) {
	local ($virt, $vconf) = &get_apache_virtual($d->{'dom'}, $port);
	next if (!$virt);
	local @locs = &apache::find_directive_struct("Location", $vconf);
	local ($loc) = grep { $_->{'words'}->[0] eq $opts->{'path'} } @locs;
	if ($loc) {
		&apache::save_directive_struct($loc, undef, $vconf, $conf);
	}
	local @sa = &apache::find_directive("Alias", $vconf);
	local ($robots) = grep { $_ =~ /^\/robots.txt/ } @sa;
	if ($robots) {
		&apache::save_directive("Alias", undef, $vconf, $conf);
		}
	local ($favicon) = grep { $_ =~ /^\/favicon.ico/ } @sa;
	if ($favicon) {
		&apache::save_directive("Alias", undef, $vconf, $conf);
		}
	local ($static) = grep { $_ =~ /^\/moin_static/ } @sa;
	if ($static) {
		&apache::save_directive("Alias", undef, $vconf, $conf);
		}
	local @sam = &apache::find_directive("ScriptAliasMatch", $vconf);
	local ($msam) = grep { $_ =~ /moin.fcgi/ } @sam;
	if ($msam) {
		&apache::save_directive("ScriptAliasMatch", undef, $vconf, $conf);
		}
	}
	&flush_file_lines($virt->{'file'});
&register_post_action(\&restart_apache);

return (1, "MoinMoin directory and tables deleted.");
}

# script_moinmoin_latest(version)
# Returns a URL and regular expression or callback func to get the version
sub script_moinmoin_latest
{
local ($ver) = @_;
return ( "http://static.moinmo.in/files/",
	 "moin-([a-z0-9\\.]+).tar.gz" );
}

sub script_moinmoin_site
{
return 'http://moinmo.in/';
}

1;

