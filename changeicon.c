#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <stdio.h>
#include <stdlib.h>

#include <ctype.h>
#include <errno.h>
#include <string.h>

static long get_property(Display *dpy, Window w, Atom prop, Atom req_type,
                          unsigned char **out_data) {
    Atom actual_type;
    int actual_format;
    unsigned long nitems, bytes_after;
    unsigned char *data = NULL;

    int status = XGetWindowProperty(dpy, w, prop, 0, (~0L), False, req_type,
                                     &actual_type, &actual_format,
                                     &nitems, &bytes_after, &data);

    if (status != Success || data == NULL || nitems == 0) {
        if (data) XFree(data);
        *out_data = NULL;
        return -1;
    }

    *out_data = data;
    return (long)nitems;
}

static unsigned long get_pid(Display *dpy, Window w) {
    Atom net_wm_pid = XInternAtom(dpy, "_NET_WM_PID", False);
    unsigned char *data = NULL;
    long n = get_property(dpy, w, net_wm_pid, XA_CARDINAL, &data);
    unsigned long pid = 0;
    if (n > 0) {
        pid = *(unsigned long *)data;
        XFree(data);
    }
    return pid;
}

static char *get_title(Display *dpy, Window w) {
    Atom net_wm_name = XInternAtom(dpy, "_NET_WM_NAME", False);
    Atom utf8_string = XInternAtom(dpy, "UTF8_STRING", False);
    unsigned char *data = NULL;
    long n = get_property(dpy, w, net_wm_name, utf8_string, &data);

    if (n > 0) {
        char *title = malloc((size_t)n + 1);
        memcpy(title, data, (size_t)n);
        title[n] = '\0';
        XFree(data);
        return title;
    }
    if (data) XFree(data);

    char *legacy = NULL;
    if (XFetchName(dpy, w, &legacy) && legacy) {
        char *title = strdup(legacy);
        XFree(legacy);
        return title;
    }

    return NULL;
}

static int isVisible(Display *dpy, Window w)
{
    XWindowAttributes attr;
    if (!XGetWindowAttributes(dpy, w, &attr))
        return 0;
    if (attr.map_state != IsViewable || attr.width <= 0 || attr.height <= 0)
        return 0;
    return 1;
}

void walk_windows(Display *dpy, Window window, unsigned long pid) //, char* title, bool ignore_case, bool child)
{
    Window root, parent;
    Window *children = NULL;
    unsigned int nchildren = 0;

    /*
     * XQueryTree returns False if the request cannot be completed.
     * Treat that as "skip this window".
     */
    if (!XQueryTree(dpy, window, &root, &parent,
                    &children, &nchildren)) {
        return;
    }

    if (!isVisible(dpy, window)) {
    	return;
    }

    //search the window
    unsigned long pid_window = get_pid(dpy, window);
    char* title_window = get_title(dpy, window);
    if (pid != 0 && pid == pid_window)
    {
		printf("Window Found: 0x%lx Window title %s\n", window, title_window);
    }

    for (unsigned int i = 0; i < nchildren; ++i) {
        walk_windows(dpy, children[i], pid);
    }

    if (children)
        XFree(children);
}

//change_icon --pid -p <pid> --title -t <regex> --ignore_case -i --child -c --set_title "title"
int main(int argc, char **argv) {
	unsigned long pid_target = strtoul(argv[1], NULL, 10);
	
	//X11 Display Server
	Display *display = XOpenDisplay(NULL);
	if (!display) {
        fprintf(stderr, "Cannot open X display (is $DISPLAY set?)\n");
        return 1;
    }

    //Walk through all windows of all screens and all children of the default root window
    int nscreens = ScreenCount(display);
    Window rootDisplay = DefaultRootWindow(display);
    walk_windows(display, rootDisplay, pid_target);
    for (int screen = 0; screen < nscreens; ++screen) {
        Window root = RootWindow(display, screen);
        if (root == rootDisplay) {
        	continue;
        }
        walk_windows(display, root, pid_target);
    }

    XCloseDisplay(display);
}

//changes the icon directly requires the icon to already be in ARGB format, length is (width * height) + 2 of the icon
void change_icon(Display *disp, Window window, unsigned long ARGB_BUFFER[], int length) {
	XChangeProperty(disp, window,
				XInternAtom(disp, "_NET_WM_ICON", False),
				XInternAtom(disp, "CARDINAL", False),
				32, PropModeReplace, (const unsigned char*) ARGB_BUFFER, length);
	XFlush(disp);
}