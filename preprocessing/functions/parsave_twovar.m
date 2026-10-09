function parsave_twovar(fname, x1, str1, x2, str2)
    eval([str1 '= x1;']);
    eval([str2 '= x2;']);
    save(fname, str1, str2, '-v7.3')
end