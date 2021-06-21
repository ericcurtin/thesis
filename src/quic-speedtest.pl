#!/usr/bin/perl

use strict;
use warnings;

use Time::HiRes qw( time );

my $file = 'quic-speedtest.cfg';
my %h;

sub read_cfg {
  open(my $info, $file) or print("Could not open $file: $!\n");
  while (my $line = <$info>) {
    chomp($line); # no newline
    $line =~ s/#.*//; # no comments
    $line =~ s/^\s+//; # no leading white
    $line =~ s/\s+$//; # no trailing white
    next unless length($line); # anything left?
    my ($var, $value) = split(/\s*=\s*/, $line, 2);
    $h{$var} = $value;
#    print("$h{$var} = $value\n");
  }

  close($info);
}

sub write_cfg {
  chdir("NVMe-QUIC/src");
  my $epoc = time();
  rename($file, "$file.$epoc");
  my $fh = open(my $info, ">", $file) or die "Could not open file '$file' $!";
  for my $k (sort keys %h) {
    print($info "$k=$h{$k}\n");
  }

  close($info);
  chdir("../..")
}

sub killall {
  # kill any servers/clients lying around
  qx(pgrep -f NVMe-QUIC/ngtcp2/examples/server | xargs -r kill);
  qx(pgrep -f NVMe-QUIC/ngtcp2/examples/client | xargs -r kill);
  qx(pgrep -f NVMe-QUIC/ngtcp2/examples/curl | xargs -r kill);
  qx(pgrep -f nghttp2/src/.libs/nghttpd | xargs -r kill);
}

sub run_server {
  killall();
  if ("$ARGV[0]" eq "tcp") {
    system("nghttp2/src/.libs/nghttpd -a 127.0.0.1 5000 key.pem cert.pem > /dev/null 2>&1 &");
  }
  else {
    system("NVMe-QUIC/ngtcp2/examples/server -q --max-data=$h{'max_data'} --max-stream-data-bidi-local=$h{'max_stream_data_bidi_local'} --max-stream-data-bidi-remote=$h{'max_stream_data_bidi_remote'} --max-stream-data-uni=$h{'max_stream_data_uni'} --max-streams-bidi=$h{'max_streams_bidi'} --max-streams-uni=$h{'max_streams_uni'} --max-dyn-length=$h{'max_dyn_length'} --max-udp-payload-size=$h{'max_udp_payload_size'} --max-window=$h{'max_window'} --max-stream-window=$h{'max_stream_window'} --max-gso-dgrams=$h{'max_gso_dgrams'} --no-quic-dump --no-http-dump 127.0.0.1 5000 key.pem cert.pem > /dev/null 2>&1 &");
  }

  sleep(0.2);
}

my $large_file = "symm/1GB.bin";

sub run_client {
  if ("$ARGV[0]" eq "tcp") {
    qx(curl -k -m 2 -w "%{time_namelookup},%{time_connect},%{time_appconnect},%{time_pretransfer},%{time_redirect},%{time_starttransfer},%{time_total},%{http_code}\n" -o /dev/null -s https://127.0.0.1:5000/$large_file);
  }
  else {
    # --download=NVMe-QUIC/src
 #   print("NVMe-QUIC/ngtcp2/examples/client -q --no-quic-dump --no-http-dump --exit-on-all-streams-close --timeout=2 --max-data=$h{'max_data_client'} --max-stream-data-bidi-local=$h{'max_stream_data_bidi_local_client'} --max-stream-data-bidi-remote=$h{'max_stream_data_bidi_remote_client'} --max-stream-data-uni=$h{'max_stream_data_uni_client'} --max-streams-bidi=$h{'max_streams_bidi_client'} --max-streams-uni=$h{'max_streams_uni_client'} --max-window=$h{'max_window_client'} --max-stream-window=$h{'max_stream_window_client'} 127.0.0.1 5000 https://127.0.0.1:5000/$large_file 2>&1\n");
#    sleep(10000);
    qx(NVMe-QUIC/ngtcp2/examples/client -q --no-quic-dump --no-http-dump --exit-on-all-streams-close --timeout=2 --max-data=$h{'max_data_client'} --max-stream-data-bidi-local=$h{'max_stream_data_bidi_local_client'} --max-stream-data-bidi-remote=$h{'max_stream_data_bidi_remote_client'} --max-stream-data-uni=$h{'max_stream_data_uni_client'} --max-streams-bidi=$h{'max_streams_bidi_client'} --max-streams-uni=$h{'max_streams_uni_client'} --max-window=$h{'max_window_client'} --max-stream-window=$h{'max_stream_window_client'} 127.0.0.1 5000 https://127.0.0.1:5000/$large_file 2>&1);
  }
}

my $duration_to_beat;
sub run_duration_to_beat {
  run_server();
  my $now = time();
  run_client();
  $duration_to_beat = time() - $now;
  print("$duration_to_beat\n");
}

my $delta = 0;
sub run_client_server {
  my $attribute = shift || 0;
  my $dont_restart_server = shift || 0;

  if ($attribute) {
    $h{$attribute} += $delta;
  }
#  if ($dont_restart_server) {
    run_server();
#  }

  my $now = time();
  run_client();
  my $duration = time() - $now;
  print("$duration\n");
  if ($attribute) {
    if ($duration > 0.4 && $duration < 0.73 && $duration < $duration_to_beat) {
      $duration_to_beat = $duration;
      write_cfg();
    }
    else {
      $h{$attribute} -= $delta;
    }
  }

}

sub run_server_with_delta {
  run_client_server('max_data');
  run_client_server('max_stream_data_bidi_local');
  run_client_server('max_stream_data_bidi_remote');
  run_client_server('max_stream_data_uni');
  run_client_server('max_streams_bidi');
  run_client_server('max_streams_uni');
  run_client_server('max_dyn_length');
  run_client_server('max_udp_payload_size');
  run_client_server('max_data');
  run_client_server('max_window');
  run_client_server('max_stream_window');
  run_client_server('max_gso_dgrams');

  run_client_server('max_data_client', 1);
  run_client_server('max_stream_data_bidi_local_client', 1);
  run_client_server('max_stream_data_bidi_remote_client', 1);
  run_client_server('max_stream_data_uni_client', 1);
  run_client_server('max_streams_bidi_client', 1);
  run_client_server('max_streams_uni_client', 1);
  run_client_server('max_window_client', 1);
  run_client_server('max_stream_window_client', 1);
}

sub reset_tc {
  qx(sudo tc qdisc del dev lo root > /dev/null 2>&1);
  qx(sudo tc -s qdisc ls dev lo > /dev/null 2>&1);
}

read_cfg();
chdir("../..");

killall();

qx(openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=localhost' 2>&1);

#print($h{'max_data'});
#for(keys %h){
#	print("Official Language of $_ is $h{$_}\n");
#}

#print("$h{'max_data'}, $h{'max_stream_data_bidi_local'}, $h{'max_stream_data_bidi_remote'}, $h{'max_stream_data_uni'}, $h{'max_streams_bidi'}, $h{'max_streams_uni'}, $h{'max_dyn_length'}, $h{'max_udp_payload_size'}, $h{'max_window'}, $h{'max_stream_window'}, $h{'max_gso_dgrams'}\n");
#run_server($h{'max_data'}, $h{'max_stream_data_bidi_local'}, $h{'max_stream_data_bidi_remote'}, $h{'max_stream_data_uni'}, $h{'max_streams_bidi'}, $h{'max_streams_uni'}, $h{'max_dyn_length'}, $h{'max_udp_payload_size'}, $h{'max_window'}, $h{'max_stream_window'}, $h{'max_gso_dgrams'});
#run_client($h{'max_data_client'}, $h{'max_stream_data_bidi_local_client'}, $h{'max_stream_data_bidi_remote_client'}, $h{'max_stream_data_uni_client'}, $h{'max_streams_bidi_client'}, $h{'max_streams_uni_client'}, $h{'max_window_client'}, $h{'max_stream_window_client'});

#if ($ARGV[0][0] eq "q") {
#  run_server_with_delta(1);
#  run_server with_delta(-1);
#}

if ("$ARGV[0]" eq "tune") {
  run_duration_to_beat();
  for (my $j = 1; $j < 10; ++$j) {
    for (my $i = 100000000 * $j; int($i) > 0; $i /= 10) {
      $delta = $i;
      run_server_with_delta();
      $delta = -$i;
      run_server_with_delta();
    }
  }
}
elsif ("$ARGV[0]" eq "quic" || "$ARGV[0]" eq "tcp") {
  print("No tc\n");
  reset_tc();
  run_client_server();

  my $packet_loss = "0.01%";
  print("Packet loss $packet_loss\n");
  qx(sudo tc qdisc add dev lo root netem loss $packet_loss);
  run_client_server();
  reset_tc();

  my $packet_duplication = "0.2%";
  print("Packet duplication $packet_duplication\n");
  qx(sudo tc qdisc add dev lo root netem duplicate $packet_duplication);
  run_client_server();
  reset_tc();

  my $packet_corruption = "0.001%";
  print("Packet corruption $packet_corruption\n");
  qx(sudo tc qdisc add dev lo root netem corrupt $packet_corruption);
  run_client_server();
  reset_tc();

  my $packet_reordering = "0.001%";
  print("Packet re-ordering $packet_reordering\n");
  qx(sudo tc qdisc add dev lo root netem loss $packet_reordering);
  run_client_server();
  reset_tc();
}

killall();

