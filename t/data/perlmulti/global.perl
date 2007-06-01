{
    domain      => 'www.test.com',
    db3         => {
                    different  => 'data',
                   },
    engine      => 'MySQL',
    testsub     => sub {'test'},
    testregex   => qr/test/,
    testobj     => bless({},'ABC'),
    list        => { a => 'b'},
}
    
            
