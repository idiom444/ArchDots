import Quickshell
import "Windows/Bar" as TopBar
import "Windows/AppLauncher" as AppLauncher

Scope {
    id: root

    AppLauncher.AppLauncher {
        id: appLauncher
    }

    TopBar.Bar {
        id: topBar
    }
}
