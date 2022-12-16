unit class Jupyter::Kernel::History;
use JSON::Tiny;
use Log::Async;
use Jupyter::Kernel::Paths;

has IO::Path $.history-file = history-file;
has Int $.session-count = 1;
has Int $.execution-count = 0;
has $!h_history;

method init {
  info "opening history file $.history-file";
  if self.read -> $lines {
    $!session-count = $lines[*-1][0] + 1;
  }
  $!h_history = try $.history-file.open(:a, :!out-buffer);
  warning "$!" if $!;
  self;
}

method read {
  return [] unless $.history-file.e;
  from-json('[' ~ $.history-file.lines.join(',') ~ ']');
}

method append($code, Int :$execution_count!) {
  return without $!h_history;
  if $execution_count != $!execution-count + 1 {
    warning "history count is wrong ($execution_count vs $!execution-count)"
  }
  $!execution-count = $execution_count;
  my $str = to-json([$.session-count, $.execution-count, $code]);
  start $!h_history.print( "$str\n" )
}
