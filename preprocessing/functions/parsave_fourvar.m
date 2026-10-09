function parsave_fourvar(fname, x1, str1, x2, str2, x3, str3, x4, str4)
    eval([str1 '= x1;']);
    eval([str2 '= x2;']);
    eval([str3 '= x3;']);
    eval([str4 '= x4;']);
    save(fname, str1, str2, str3, str4, '-v7.3')
end