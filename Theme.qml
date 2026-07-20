pragma Singleton
import Quickshell

Singleton {

  property var __themes: ({
      "vague": {
        "fg": "#cdcdcd",
        "bg": "#101011",
        "black": "#252530" // Black
        ,
        "black2": "#606079" // Bright Black (Gray)
        ,
        "red": "#d8647e" // Red
        ,
        "red2": "#e08398" // Bright Red
        ,
        "green": "#7fa563" // Green
        ,
        "green2": "#79fa8f" // Bright Green
        ,
        "yellow": "#f3be7c" // Yellow
        ,
        "yellow2": "#f5cb96" // Bright Yellow
        ,
        "blue": "#6e94b2" // Blue
        ,
        "blue2": "#8ba9c1" // Bright Blue
        ,
        "magenta": "#bb9dbd" // Magenta
        ,
        "magenta2": "#c9b1ca" // Bright Magenta
        ,
        "cyan": "#aeaed1" // Cyan
        ,
        "cyan2": "#bebeda" // Bright Cyan
        ,
        "white": "#cdcdcd" // White
        ,
        "white2": "#d7d7d7"  // Bright White
      }
  })
  property string current_theme: "vague"
  readonly property var c: __themes[current_theme]
  property string clock_font: "Liberation Sans"

}
