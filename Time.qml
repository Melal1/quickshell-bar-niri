pragma Singleton
import Quickshell

Singleton {
  readonly property alias date: clock.date

  SystemClock {
    id: clock
    precision: Settings.clock_sec ? SystemClock.Seconds : SystemClock.Minutes
  }
}
