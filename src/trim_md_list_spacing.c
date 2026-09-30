
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#define TAB_WIDTH 2

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("Usage: trim_md_list_spacing <FILE> <TAB_WIDTH>\n");
        return 1;
    }

    // tab width
    int tab_width = TAB_WIDTH;
    if (argc > 2) {
        tab_width = atoi(argv[2]);
        if (!tab_width) tab_width = TAB_WIDTH;
    }
    printf("Tab width is %d\n", tab_width);

    // file names
    char *file_name = argv[1];
    char tmp_file_name[256];
    int n = snprintf(tmp_file_name, 256, "%s.tmp", argv[1]);
    tmp_file_name[n] = '\0';

    // file pointers
    FILE *ifp = fopen(file_name, "r");
    if (!ifp) {
        printf("Could not find input file %s\n", file_name);
        return 1;
    }
    FILE *ofp = fopen(tmp_file_name, "w");

    // buffer
    int new_lines = 0;
    bool prev_line_is_list = false;
    char *line = NULL;
    size_t len = 0;
    ssize_t read;

    // read input
    while ((read = getline(&line, &len, ifp)) != -1) {
        //printf("Line has length %d %d\n", len, read);
        if (read == 1) {
            ++new_lines;
            //printf("Blank line\n");
        }
        else {
            // normalize line ending
            if (read >= 2) {
                if (line[read-2] == '\r') {
                    line[read-2] = '\n';
                    line[read-1] = '\0';
                }
            }

            // find first character
            n = 0;
            bool all_spaces = true;
            while (line[n] && line[n] <= ' ' && n < read) {
                all_spaces = all_spaces && line[n] == ' ';
                ++n;
            }
            if (n == read) {
                new_lines++;
                //printf("Blank line\n");
                continue;
            }
            //printf("New line '%s' starts with '%c' (%d)\n", line, line[n], n);

            char c = line[n];
            bool is_list = false;
            char *line_with_indents = line;
            if (c == '*' || c == '-') {
                is_list = true;
                line[n] = '-';
                if (tab_width && all_spaces) {
                    int num_indents = n / tab_width;
                    int tab_start = n - num_indents;
                    for (int i = tab_start; i < n; ++i) {
                        line[i] = '\t';
                    }
                    line_with_indents = &line[tab_start];
                    //printf("All spaces (%d) before list, converted to %d indentations (width %d) starting at character %d (%d vs %d)\n", n, num_indents, tab_width, tab_start, (unsigned int)line, (unsigned int)line_with_indents);
                }
            }

            // Insert new lines
            if ((!is_list || !prev_line_is_list) && new_lines > 0) {
                while (new_lines--) {
                    fprintf(ofp, "\n");
                }
            }
            new_lines = 0;

            // Write content
            fprintf(ofp, "%s", line_with_indents);

            // remember type of line
            prev_line_is_list = is_list;
        }
    }

    fclose(ifp);
    fclose(ofp);
    if (line) {
        free(line);
    }

    // move temporary file to original file
    n = rename(tmp_file_name, file_name);
    if (n) {
        printf("Rename returned %d and could not overwrite the original file.\n", n);
        printf("  Please execute the following command:\n\n");
        printf("  mv %s %s\n", tmp_file_name, file_name);
    }
    return 0;

}
