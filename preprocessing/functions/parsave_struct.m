function parsave_struct(fname, x, str)
    eval([str '= x;']);
    save(fname, '-v7.3', '-struct', str)
end