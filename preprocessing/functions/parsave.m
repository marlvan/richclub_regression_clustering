function parsave(fname, x, str)
    eval([str '= x;']);
    save(fname, '-v7.3', str)
end