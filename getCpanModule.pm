package getCpanModule;
no strict 'refs';
sub loadCpanModule {
    `curl -o $_[1].pm '$_[2]'`;
    `mkdir $_[0]`;
    `mv $_[1].pm $_[0]`;
}
1;
