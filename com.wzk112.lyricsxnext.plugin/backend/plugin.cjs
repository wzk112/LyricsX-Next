var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __commonJS = (cb, mod) => function __require() {
  try {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  } catch (e) {
    throw mod = 0, e;
  }
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// node_modules/logform/format.js
var require_format = __commonJS({
  "node_modules/logform/format.js"(exports2, module2) {
    "use strict";
    var InvalidFormatError = class _InvalidFormatError extends Error {
      constructor(formatFn) {
        super(`Format functions must be synchronous taking a two arguments: (info, opts)
Found: ${formatFn.toString().split("\n")[0]}
`);
        Error.captureStackTrace(this, _InvalidFormatError);
      }
    };
    module2.exports = (formatFn) => {
      if (formatFn.length > 2) {
        throw new InvalidFormatError(formatFn);
      }
      function Format(options = {}) {
        this.options = options;
      }
      Format.prototype.transform = formatFn;
      function createFormatWrap(opts) {
        return new Format(opts);
      }
      createFormatWrap.Format = Format;
      return createFormatWrap;
    };
  }
});

// node_modules/logform/node_modules/@colors/colors/lib/styles.js
var require_styles = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/lib/styles.js"(exports2, module2) {
    var styles = {};
    module2["exports"] = styles;
    var codes = {
      reset: [0, 0],
      bold: [1, 22],
      dim: [2, 22],
      italic: [3, 23],
      underline: [4, 24],
      inverse: [7, 27],
      hidden: [8, 28],
      strikethrough: [9, 29],
      black: [30, 39],
      red: [31, 39],
      green: [32, 39],
      yellow: [33, 39],
      blue: [34, 39],
      magenta: [35, 39],
      cyan: [36, 39],
      white: [37, 39],
      gray: [90, 39],
      grey: [90, 39],
      brightRed: [91, 39],
      brightGreen: [92, 39],
      brightYellow: [93, 39],
      brightBlue: [94, 39],
      brightMagenta: [95, 39],
      brightCyan: [96, 39],
      brightWhite: [97, 39],
      bgBlack: [40, 49],
      bgRed: [41, 49],
      bgGreen: [42, 49],
      bgYellow: [43, 49],
      bgBlue: [44, 49],
      bgMagenta: [45, 49],
      bgCyan: [46, 49],
      bgWhite: [47, 49],
      bgGray: [100, 49],
      bgGrey: [100, 49],
      bgBrightRed: [101, 49],
      bgBrightGreen: [102, 49],
      bgBrightYellow: [103, 49],
      bgBrightBlue: [104, 49],
      bgBrightMagenta: [105, 49],
      bgBrightCyan: [106, 49],
      bgBrightWhite: [107, 49],
      // legacy styles for colors pre v1.0.0
      blackBG: [40, 49],
      redBG: [41, 49],
      greenBG: [42, 49],
      yellowBG: [43, 49],
      blueBG: [44, 49],
      magentaBG: [45, 49],
      cyanBG: [46, 49],
      whiteBG: [47, 49]
    };
    Object.keys(codes).forEach(function(key) {
      var val = codes[key];
      var style = styles[key] = [];
      style.open = "\x1B[" + val[0] + "m";
      style.close = "\x1B[" + val[1] + "m";
    });
  }
});

// node_modules/logform/node_modules/@colors/colors/lib/system/has-flag.js
var require_has_flag = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/lib/system/has-flag.js"(exports2, module2) {
    "use strict";
    module2.exports = function(flag, argv) {
      argv = argv || process.argv || [];
      var terminatorPos = argv.indexOf("--");
      var prefix = /^-{1,2}/.test(flag) ? "" : "--";
      var pos = argv.indexOf(prefix + flag);
      return pos !== -1 && (terminatorPos === -1 ? true : pos < terminatorPos);
    };
  }
});

// node_modules/logform/node_modules/@colors/colors/lib/system/supports-colors.js
var require_supports_colors = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/lib/system/supports-colors.js"(exports2, module2) {
    "use strict";
    var os2 = require("os");
    var hasFlag = require_has_flag();
    var env = process.env;
    var forceColor = void 0;
    if (hasFlag("no-color") || hasFlag("no-colors") || hasFlag("color=false")) {
      forceColor = false;
    } else if (hasFlag("color") || hasFlag("colors") || hasFlag("color=true") || hasFlag("color=always")) {
      forceColor = true;
    }
    if ("FORCE_COLOR" in env) {
      forceColor = env.FORCE_COLOR.length === 0 || parseInt(env.FORCE_COLOR, 10) !== 0;
    }
    function translateLevel(level) {
      if (level === 0) {
        return false;
      }
      return {
        level,
        hasBasic: true,
        has256: level >= 2,
        has16m: level >= 3
      };
    }
    function supportsColor(stream) {
      if (forceColor === false) {
        return 0;
      }
      if (hasFlag("color=16m") || hasFlag("color=full") || hasFlag("color=truecolor")) {
        return 3;
      }
      if (hasFlag("color=256")) {
        return 2;
      }
      if (stream && !stream.isTTY && forceColor !== true) {
        return 0;
      }
      var min = forceColor ? 1 : 0;
      if (process.platform === "win32") {
        var osRelease = os2.release().split(".");
        if (Number(process.versions.node.split(".")[0]) >= 8 && Number(osRelease[0]) >= 10 && Number(osRelease[2]) >= 10586) {
          return Number(osRelease[2]) >= 14931 ? 3 : 2;
        }
        return 1;
      }
      if ("CI" in env) {
        if (["TRAVIS", "CIRCLECI", "APPVEYOR", "GITLAB_CI"].some(function(sign) {
          return sign in env;
        }) || env.CI_NAME === "codeship") {
          return 1;
        }
        return min;
      }
      if ("TEAMCITY_VERSION" in env) {
        return /^(9\.(0*[1-9]\d*)\.|\d{2,}\.)/.test(env.TEAMCITY_VERSION) ? 1 : 0;
      }
      if ("TERM_PROGRAM" in env) {
        var version = parseInt((env.TERM_PROGRAM_VERSION || "").split(".")[0], 10);
        switch (env.TERM_PROGRAM) {
          case "iTerm.app":
            return version >= 3 ? 3 : 2;
          case "Hyper":
            return 3;
          case "Apple_Terminal":
            return 2;
        }
      }
      if (/-256(color)?$/i.test(env.TERM)) {
        return 2;
      }
      if (/^screen|^xterm|^vt100|^rxvt|color|ansi|cygwin|linux/i.test(env.TERM)) {
        return 1;
      }
      if ("COLORTERM" in env) {
        return 1;
      }
      if (env.TERM === "dumb") {
        return min;
      }
      return min;
    }
    function getSupportLevel(stream) {
      var level = supportsColor(stream);
      return translateLevel(level);
    }
    module2.exports = {
      supportsColor: getSupportLevel,
      stdout: getSupportLevel(process.stdout),
      stderr: getSupportLevel(process.stderr)
    };
  }
});

// node_modules/logform/node_modules/@colors/colors/lib/custom/trap.js
var require_trap = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/lib/custom/trap.js"(exports2, module2) {
    module2["exports"] = function runTheTrap(text, options) {
      var result = "";
      text = text || "Run the trap, drop the bass";
      text = text.split("");
      var trap = {
        a: ["@", "\u0104", "\u023A", "\u0245", "\u0394", "\u039B", "\u0414"],
        b: ["\xDF", "\u0181", "\u0243", "\u026E", "\u03B2", "\u0E3F"],
        c: ["\xA9", "\u023B", "\u03FE"],
        d: ["\xD0", "\u018A", "\u0500", "\u0501", "\u0502", "\u0503"],
        e: [
          "\xCB",
          "\u0115",
          "\u018E",
          "\u0258",
          "\u03A3",
          "\u03BE",
          "\u04BC",
          "\u0A6C"
        ],
        f: ["\u04FA"],
        g: ["\u0262"],
        h: ["\u0126", "\u0195", "\u04A2", "\u04BA", "\u04C7", "\u050A"],
        i: ["\u0F0F"],
        j: ["\u0134"],
        k: ["\u0138", "\u04A0", "\u04C3", "\u051E"],
        l: ["\u0139"],
        m: ["\u028D", "\u04CD", "\u04CE", "\u0520", "\u0521", "\u0D69"],
        n: ["\xD1", "\u014B", "\u019D", "\u0376", "\u03A0", "\u048A"],
        o: [
          "\xD8",
          "\xF5",
          "\xF8",
          "\u01FE",
          "\u0298",
          "\u047A",
          "\u05DD",
          "\u06DD",
          "\u0E4F"
        ],
        p: ["\u01F7", "\u048E"],
        q: ["\u09CD"],
        r: ["\xAE", "\u01A6", "\u0210", "\u024C", "\u0280", "\u042F"],
        s: ["\xA7", "\u03DE", "\u03DF", "\u03E8"],
        t: ["\u0141", "\u0166", "\u0373"],
        u: ["\u01B1", "\u054D"],
        v: ["\u05D8"],
        w: ["\u0428", "\u0460", "\u047C", "\u0D70"],
        x: ["\u04B2", "\u04FE", "\u04FC", "\u04FD"],
        y: ["\xA5", "\u04B0", "\u04CB"],
        z: ["\u01B5", "\u0240"]
      };
      text.forEach(function(c) {
        c = c.toLowerCase();
        var chars = trap[c] || [" "];
        var rand = Math.floor(Math.random() * chars.length);
        if (typeof trap[c] !== "undefined") {
          result += trap[c][rand];
        } else {
          result += c;
        }
      });
      return result;
    };
  }
});

// node_modules/logform/node_modules/@colors/colors/lib/custom/zalgo.js
var require_zalgo = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/lib/custom/zalgo.js"(exports2, module2) {
    module2["exports"] = function zalgo(text, options) {
      text = text || "   he is here   ";
      var soul = {
        "up": [
          "\u030D",
          "\u030E",
          "\u0304",
          "\u0305",
          "\u033F",
          "\u0311",
          "\u0306",
          "\u0310",
          "\u0352",
          "\u0357",
          "\u0351",
          "\u0307",
          "\u0308",
          "\u030A",
          "\u0342",
          "\u0313",
          "\u0308",
          "\u034A",
          "\u034B",
          "\u034C",
          "\u0303",
          "\u0302",
          "\u030C",
          "\u0350",
          "\u0300",
          "\u0301",
          "\u030B",
          "\u030F",
          "\u0312",
          "\u0313",
          "\u0314",
          "\u033D",
          "\u0309",
          "\u0363",
          "\u0364",
          "\u0365",
          "\u0366",
          "\u0367",
          "\u0368",
          "\u0369",
          "\u036A",
          "\u036B",
          "\u036C",
          "\u036D",
          "\u036E",
          "\u036F",
          "\u033E",
          "\u035B",
          "\u0346",
          "\u031A"
        ],
        "down": [
          "\u0316",
          "\u0317",
          "\u0318",
          "\u0319",
          "\u031C",
          "\u031D",
          "\u031E",
          "\u031F",
          "\u0320",
          "\u0324",
          "\u0325",
          "\u0326",
          "\u0329",
          "\u032A",
          "\u032B",
          "\u032C",
          "\u032D",
          "\u032E",
          "\u032F",
          "\u0330",
          "\u0331",
          "\u0332",
          "\u0333",
          "\u0339",
          "\u033A",
          "\u033B",
          "\u033C",
          "\u0345",
          "\u0347",
          "\u0348",
          "\u0349",
          "\u034D",
          "\u034E",
          "\u0353",
          "\u0354",
          "\u0355",
          "\u0356",
          "\u0359",
          "\u035A",
          "\u0323"
        ],
        "mid": [
          "\u0315",
          "\u031B",
          "\u0300",
          "\u0301",
          "\u0358",
          "\u0321",
          "\u0322",
          "\u0327",
          "\u0328",
          "\u0334",
          "\u0335",
          "\u0336",
          "\u035C",
          "\u035D",
          "\u035E",
          "\u035F",
          "\u0360",
          "\u0362",
          "\u0338",
          "\u0337",
          "\u0361",
          " \u0489"
        ]
      };
      var all = [].concat(soul.up, soul.down, soul.mid);
      function randomNumber(range) {
        var r = Math.floor(Math.random() * range);
        return r;
      }
      function isChar(character) {
        var bool = false;
        all.filter(function(i) {
          bool = i === character;
        });
        return bool;
      }
      function heComes(text2, options2) {
        var result = "";
        var counts;
        var l;
        options2 = options2 || {};
        options2["up"] = typeof options2["up"] !== "undefined" ? options2["up"] : true;
        options2["mid"] = typeof options2["mid"] !== "undefined" ? options2["mid"] : true;
        options2["down"] = typeof options2["down"] !== "undefined" ? options2["down"] : true;
        options2["size"] = typeof options2["size"] !== "undefined" ? options2["size"] : "maxi";
        text2 = text2.split("");
        for (l in text2) {
          if (isChar(l)) {
            continue;
          }
          result = result + text2[l];
          counts = { "up": 0, "down": 0, "mid": 0 };
          switch (options2.size) {
            case "mini":
              counts.up = randomNumber(8);
              counts.mid = randomNumber(2);
              counts.down = randomNumber(8);
              break;
            case "maxi":
              counts.up = randomNumber(16) + 3;
              counts.mid = randomNumber(4) + 1;
              counts.down = randomNumber(64) + 3;
              break;
            default:
              counts.up = randomNumber(8) + 1;
              counts.mid = randomNumber(6) / 2;
              counts.down = randomNumber(8) + 1;
              break;
          }
          var arr = ["up", "mid", "down"];
          for (var d in arr) {
            var index = arr[d];
            for (var i = 0; i <= counts[index]; i++) {
              if (options2[index]) {
                result = result + soul[index][randomNumber(soul[index].length)];
              }
            }
          }
        }
        return result;
      }
      return heComes(text, options);
    };
  }
});

// node_modules/logform/node_modules/@colors/colors/lib/maps/america.js
var require_america = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/lib/maps/america.js"(exports2, module2) {
    module2["exports"] = function(colors) {
      return function(letter, i, exploded) {
        if (letter === " ") return letter;
        switch (i % 3) {
          case 0:
            return colors.red(letter);
          case 1:
            return colors.white(letter);
          case 2:
            return colors.blue(letter);
        }
      };
    };
  }
});

// node_modules/logform/node_modules/@colors/colors/lib/maps/zebra.js
var require_zebra = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/lib/maps/zebra.js"(exports2, module2) {
    module2["exports"] = function(colors) {
      return function(letter, i, exploded) {
        return i % 2 === 0 ? letter : colors.inverse(letter);
      };
    };
  }
});

// node_modules/logform/node_modules/@colors/colors/lib/maps/rainbow.js
var require_rainbow = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/lib/maps/rainbow.js"(exports2, module2) {
    module2["exports"] = function(colors) {
      var rainbowColors = ["red", "yellow", "green", "blue", "magenta"];
      return function(letter, i, exploded) {
        if (letter === " ") {
          return letter;
        } else {
          return colors[rainbowColors[i++ % rainbowColors.length]](letter);
        }
      };
    };
  }
});

// node_modules/logform/node_modules/@colors/colors/lib/maps/random.js
var require_random = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/lib/maps/random.js"(exports2, module2) {
    module2["exports"] = function(colors) {
      var available = [
        "underline",
        "inverse",
        "grey",
        "yellow",
        "red",
        "green",
        "blue",
        "white",
        "cyan",
        "magenta",
        "brightYellow",
        "brightRed",
        "brightGreen",
        "brightBlue",
        "brightWhite",
        "brightCyan",
        "brightMagenta"
      ];
      return function(letter, i, exploded) {
        return letter === " " ? letter : colors[available[Math.round(Math.random() * (available.length - 2))]](letter);
      };
    };
  }
});

// node_modules/logform/node_modules/@colors/colors/lib/colors.js
var require_colors = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/lib/colors.js"(exports2, module2) {
    var colors = {};
    module2["exports"] = colors;
    colors.themes = {};
    var util = require("util");
    var ansiStyles = colors.styles = require_styles();
    var defineProps = Object.defineProperties;
    var newLineRegex = new RegExp(/[\r\n]+/g);
    colors.supportsColor = require_supports_colors().supportsColor;
    if (typeof colors.enabled === "undefined") {
      colors.enabled = colors.supportsColor() !== false;
    }
    colors.enable = function() {
      colors.enabled = true;
    };
    colors.disable = function() {
      colors.enabled = false;
    };
    colors.stripColors = colors.strip = function(str) {
      return ("" + str).replace(/\x1B\[\d+m/g, "");
    };
    var stylize = colors.stylize = function stylize2(str, style) {
      if (!colors.enabled) {
        return str + "";
      }
      var styleMap = ansiStyles[style];
      if (!styleMap && style in colors) {
        return colors[style](str);
      }
      return styleMap.open + str + styleMap.close;
    };
    var matchOperatorsRe = /[|\\{}()[\]^$+*?.]/g;
    var escapeStringRegexp = function(str) {
      if (typeof str !== "string") {
        throw new TypeError("Expected a string");
      }
      return str.replace(matchOperatorsRe, "\\$&");
    };
    function build(_styles) {
      var builder = function builder2() {
        return applyStyle.apply(builder2, arguments);
      };
      builder._styles = _styles;
      builder.__proto__ = proto;
      return builder;
    }
    var styles = (function() {
      var ret = {};
      ansiStyles.grey = ansiStyles.gray;
      Object.keys(ansiStyles).forEach(function(key) {
        ansiStyles[key].closeRe = new RegExp(escapeStringRegexp(ansiStyles[key].close), "g");
        ret[key] = {
          get: function() {
            return build(this._styles.concat(key));
          }
        };
      });
      return ret;
    })();
    var proto = defineProps(function colors2() {
    }, styles);
    function applyStyle() {
      var args = Array.prototype.slice.call(arguments);
      var str = args.map(function(arg) {
        if (arg != null && arg.constructor === String) {
          return arg;
        } else {
          return util.inspect(arg);
        }
      }).join(" ");
      if (!colors.enabled || !str) {
        return str;
      }
      var newLinesPresent = str.indexOf("\n") != -1;
      var nestedStyles = this._styles;
      var i = nestedStyles.length;
      while (i--) {
        var code = ansiStyles[nestedStyles[i]];
        str = code.open + str.replace(code.closeRe, code.open) + code.close;
        if (newLinesPresent) {
          str = str.replace(newLineRegex, function(match) {
            return code.close + match + code.open;
          });
        }
      }
      return str;
    }
    colors.setTheme = function(theme) {
      if (typeof theme === "string") {
        console.log("colors.setTheme now only accepts an object, not a string.  If you are trying to set a theme from a file, it is now your (the caller's) responsibility to require the file.  The old syntax looked like colors.setTheme(__dirname + '/../themes/generic-logging.js'); The new syntax looks like colors.setTheme(require(__dirname + '/../themes/generic-logging.js'));");
        return;
      }
      for (var style in theme) {
        (function(style2) {
          colors[style2] = function(str) {
            if (typeof theme[style2] === "object") {
              var out = str;
              for (var i in theme[style2]) {
                out = colors[theme[style2][i]](out);
              }
              return out;
            }
            return colors[theme[style2]](str);
          };
        })(style);
      }
    };
    function init() {
      var ret = {};
      Object.keys(styles).forEach(function(name) {
        ret[name] = {
          get: function() {
            return build([name]);
          }
        };
      });
      return ret;
    }
    var sequencer = function sequencer2(map2, str) {
      var exploded = str.split("");
      exploded = exploded.map(map2);
      return exploded.join("");
    };
    colors.trap = require_trap();
    colors.zalgo = require_zalgo();
    colors.maps = {};
    colors.maps.america = require_america()(colors);
    colors.maps.zebra = require_zebra()(colors);
    colors.maps.rainbow = require_rainbow()(colors);
    colors.maps.random = require_random()(colors);
    for (map in colors.maps) {
      (function(map2) {
        colors[map2] = function(str) {
          return sequencer(colors.maps[map2], str);
        };
      })(map);
    }
    var map;
    defineProps(colors, init());
  }
});

// node_modules/logform/node_modules/@colors/colors/safe.js
var require_safe = __commonJS({
  "node_modules/logform/node_modules/@colors/colors/safe.js"(exports2, module2) {
    var colors = require_colors();
    module2["exports"] = colors;
  }
});

// node_modules/triple-beam/config/cli.js
var require_cli = __commonJS({
  "node_modules/triple-beam/config/cli.js"(exports2) {
    "use strict";
    exports2.levels = {
      error: 0,
      warn: 1,
      help: 2,
      data: 3,
      info: 4,
      debug: 5,
      prompt: 6,
      verbose: 7,
      input: 8,
      silly: 9
    };
    exports2.colors = {
      error: "red",
      warn: "yellow",
      help: "cyan",
      data: "grey",
      info: "green",
      debug: "blue",
      prompt: "grey",
      verbose: "cyan",
      input: "grey",
      silly: "magenta"
    };
  }
});

// node_modules/triple-beam/config/npm.js
var require_npm = __commonJS({
  "node_modules/triple-beam/config/npm.js"(exports2) {
    "use strict";
    exports2.levels = {
      error: 0,
      warn: 1,
      info: 2,
      http: 3,
      verbose: 4,
      debug: 5,
      silly: 6
    };
    exports2.colors = {
      error: "red",
      warn: "yellow",
      info: "green",
      http: "green",
      verbose: "cyan",
      debug: "blue",
      silly: "magenta"
    };
  }
});

// node_modules/triple-beam/config/syslog.js
var require_syslog = __commonJS({
  "node_modules/triple-beam/config/syslog.js"(exports2) {
    "use strict";
    exports2.levels = {
      emerg: 0,
      alert: 1,
      crit: 2,
      error: 3,
      warning: 4,
      notice: 5,
      info: 6,
      debug: 7
    };
    exports2.colors = {
      emerg: "red",
      alert: "yellow",
      crit: "red",
      error: "red",
      warning: "red",
      notice: "yellow",
      info: "green",
      debug: "blue"
    };
  }
});

// node_modules/triple-beam/config/index.js
var require_config = __commonJS({
  "node_modules/triple-beam/config/index.js"(exports2) {
    "use strict";
    Object.defineProperty(exports2, "cli", {
      value: require_cli()
    });
    Object.defineProperty(exports2, "npm", {
      value: require_npm()
    });
    Object.defineProperty(exports2, "syslog", {
      value: require_syslog()
    });
  }
});

// node_modules/triple-beam/index.js
var require_triple_beam = __commonJS({
  "node_modules/triple-beam/index.js"(exports2) {
    "use strict";
    Object.defineProperty(exports2, "LEVEL", {
      value: /* @__PURE__ */ Symbol.for("level")
    });
    Object.defineProperty(exports2, "MESSAGE", {
      value: /* @__PURE__ */ Symbol.for("message")
    });
    Object.defineProperty(exports2, "SPLAT", {
      value: /* @__PURE__ */ Symbol.for("splat")
    });
    Object.defineProperty(exports2, "configs", {
      value: require_config()
    });
  }
});

// node_modules/logform/colorize.js
var require_colorize = __commonJS({
  "node_modules/logform/colorize.js"(exports2, module2) {
    "use strict";
    var colors = require_safe();
    var { LEVEL, MESSAGE } = require_triple_beam();
    colors.enabled = true;
    var hasSpace = /\s+/;
    var Colorizer = class _Colorizer {
      constructor(opts = {}) {
        if (opts.colors) {
          this.addColors(opts.colors);
        }
        this.options = opts;
      }
      /*
       * Adds the colors Object to the set of allColors
       * known by the Colorizer
       *
       * @param {Object} colors Set of color mappings to add.
       */
      static addColors(clrs) {
        const nextColors = Object.keys(clrs).reduce((acc, level) => {
          acc[level] = hasSpace.test(clrs[level]) ? clrs[level].split(hasSpace) : clrs[level];
          return acc;
        }, {});
        _Colorizer.allColors = Object.assign({}, _Colorizer.allColors || {}, nextColors);
        return _Colorizer.allColors;
      }
      /*
       * Adds the colors Object to the set of allColors
       * known by the Colorizer
       *
       * @param {Object} colors Set of color mappings to add.
       */
      addColors(clrs) {
        return _Colorizer.addColors(clrs);
      }
      /*
       * function colorize (lookup, level, message)
       * Performs multi-step colorization using @colors/colors/safe
       */
      colorize(lookup, level, message) {
        if (typeof message === "undefined") {
          message = level;
        }
        if (!Array.isArray(_Colorizer.allColors[lookup])) {
          return colors[_Colorizer.allColors[lookup]](message);
        }
        for (let i = 0, len = _Colorizer.allColors[lookup].length; i < len; i++) {
          message = colors[_Colorizer.allColors[lookup][i]](message);
        }
        return message;
      }
      /*
       * function transform (info, opts)
       * Attempts to colorize the { level, message } of the given
       * `logform` info object.
       */
      transform(info, opts) {
        if (opts.all && typeof info[MESSAGE] === "string") {
          info[MESSAGE] = this.colorize(info[LEVEL], info.level, info[MESSAGE]);
        }
        if (opts.level || opts.all || !opts.message) {
          info.level = this.colorize(info[LEVEL], info.level);
        }
        if (opts.all || opts.message) {
          info.message = this.colorize(info[LEVEL], info.level, info.message);
        }
        return info;
      }
    };
    module2.exports = (opts) => new Colorizer(opts);
    module2.exports.Colorizer = module2.exports.Format = Colorizer;
  }
});

// node_modules/logform/levels.js
var require_levels = __commonJS({
  "node_modules/logform/levels.js"(exports2, module2) {
    "use strict";
    var { Colorizer } = require_colorize();
    module2.exports = (config) => {
      Colorizer.addColors(config.colors || config);
      return config;
    };
  }
});

// node_modules/logform/align.js
var require_align = __commonJS({
  "node_modules/logform/align.js"(exports2, module2) {
    "use strict";
    var format = require_format();
    module2.exports = format((info) => {
      info.message = `	${info.message}`;
      return info;
    });
  }
});

// node_modules/logform/errors.js
var require_errors = __commonJS({
  "node_modules/logform/errors.js"(exports2, module2) {
    "use strict";
    var format = require_format();
    var { LEVEL, MESSAGE } = require_triple_beam();
    module2.exports = format((einfo, { stack, cause }) => {
      if (einfo instanceof Error) {
        const info = Object.assign({}, einfo, {
          level: einfo.level,
          [LEVEL]: einfo[LEVEL] || einfo.level,
          message: einfo.message,
          [MESSAGE]: einfo[MESSAGE] || einfo.message
        });
        if (stack) info.stack = einfo.stack;
        if (cause) info.cause = einfo.cause;
        return info;
      }
      if (!(einfo.message instanceof Error)) return einfo;
      const err = einfo.message;
      Object.assign(einfo, err);
      einfo.message = err.message;
      einfo[MESSAGE] = err.message;
      if (stack) einfo.stack = err.stack;
      if (cause) einfo.cause = err.cause;
      return einfo;
    });
  }
});

// node_modules/logform/pad-levels.js
var require_pad_levels = __commonJS({
  "node_modules/logform/pad-levels.js"(exports2, module2) {
    "use strict";
    var { configs, LEVEL, MESSAGE } = require_triple_beam();
    var Padder = class _Padder {
      constructor(opts = { levels: configs.npm.levels }) {
        this.paddings = _Padder.paddingForLevels(opts.levels, opts.filler);
        this.options = opts;
      }
      /**
       * Returns the maximum length of keys in the specified `levels` Object.
       * @param  {Object} levels Set of all levels to calculate longest level against.
       * @returns {Number} Maximum length of the longest level string.
       */
      static getLongestLevel(levels) {
        const lvls = Object.keys(levels).map((level) => level.length);
        return Math.max(...lvls);
      }
      /**
       * Returns the padding for the specified `level` assuming that the
       * maximum length of all levels it's associated with is `maxLength`.
       * @param  {String} level Level to calculate padding for.
       * @param  {String} filler Repeatable text to use for padding.
       * @param  {Number} maxLength Length of the longest level
       * @returns {String} Padding string for the `level`
       */
      static paddingForLevel(level, filler, maxLength) {
        const targetLen = maxLength + 1 - level.length;
        const rep = Math.floor(targetLen / filler.length);
        const padding = `${filler}${filler.repeat(rep)}`;
        return padding.slice(0, targetLen);
      }
      /**
       * Returns an object with the string paddings for the given `levels`
       * using the specified `filler`.
       * @param  {Object} levels Set of all levels to calculate padding for.
       * @param  {String} filler Repeatable text to use for padding.
       * @returns {Object} Mapping of level to desired padding.
       */
      static paddingForLevels(levels, filler = " ") {
        const maxLength = _Padder.getLongestLevel(levels);
        return Object.keys(levels).reduce((acc, level) => {
          acc[level] = _Padder.paddingForLevel(level, filler, maxLength);
          return acc;
        }, {});
      }
      /**
       * Prepends the padding onto the `message` based on the `LEVEL` of
       * the `info`. This is based on the behavior of `winston@2` which also
       * prepended the level onto the message.
       *
       * See: https://github.com/winstonjs/winston/blob/2.x/lib/winston/logger.js#L198-L201
       *
       * @param  {Info} info Logform info object
       * @param  {Object} opts Options passed along to this instance.
       * @returns {Info} Modified logform info object.
       */
      transform(info, opts) {
        info.message = `${this.paddings[info[LEVEL]]}${info.message}`;
        if (info[MESSAGE]) {
          info[MESSAGE] = `${this.paddings[info[LEVEL]]}${info[MESSAGE]}`;
        }
        return info;
      }
    };
    module2.exports = (opts) => new Padder(opts);
    module2.exports.Padder = module2.exports.Format = Padder;
  }
});

// node_modules/logform/cli.js
var require_cli2 = __commonJS({
  "node_modules/logform/cli.js"(exports2, module2) {
    "use strict";
    var { Colorizer } = require_colorize();
    var { Padder } = require_pad_levels();
    var { configs, MESSAGE } = require_triple_beam();
    var CliFormat = class {
      constructor(opts = {}) {
        if (!opts.levels) {
          opts.levels = configs.cli.levels;
        }
        this.colorizer = new Colorizer(opts);
        this.padder = new Padder(opts);
        this.options = opts;
      }
      /*
       * function transform (info, opts)
       * Attempts to both:
       * 1. Pad the { level }
       * 2. Colorize the { level, message }
       * of the given `logform` info object depending on the `opts`.
       */
      transform(info, opts) {
        this.colorizer.transform(
          this.padder.transform(info, opts),
          opts
        );
        info[MESSAGE] = `${info.level}:${info.message}`;
        return info;
      }
    };
    module2.exports = (opts) => new CliFormat(opts);
    module2.exports.Format = CliFormat;
  }
});

// node_modules/logform/combine.js
var require_combine = __commonJS({
  "node_modules/logform/combine.js"(exports2, module2) {
    "use strict";
    var format = require_format();
    function cascade(formats) {
      if (!formats.every(isValidFormat)) {
        return;
      }
      return (info) => {
        let obj = info;
        for (let i = 0; i < formats.length; i++) {
          obj = formats[i].transform(obj, formats[i].options);
          if (!obj) {
            return false;
          }
        }
        return obj;
      };
    }
    function isValidFormat(fmt) {
      if (typeof fmt.transform !== "function") {
        throw new Error([
          "No transform function found on format. Did you create a format instance?",
          "const myFormat = format(formatFn);",
          "const instance = myFormat();"
        ].join("\n"));
      }
      return true;
    }
    module2.exports = (...formats) => {
      const combinedFormat = format(cascade(formats));
      const instance = combinedFormat();
      instance.Format = combinedFormat.Format;
      return instance;
    };
    module2.exports.cascade = cascade;
  }
});

// node_modules/safe-stable-stringify/index.js
var require_safe_stable_stringify = __commonJS({
  "node_modules/safe-stable-stringify/index.js"(exports2, module2) {
    "use strict";
    var { hasOwnProperty } = Object.prototype;
    var stringify = configure();
    stringify.configure = configure;
    stringify.stringify = stringify;
    stringify.default = stringify;
    exports2.stringify = stringify;
    exports2.configure = configure;
    module2.exports = stringify;
    var strEscapeSequencesRegExp = /[\u0000-\u001f\u0022\u005c\ud800-\udfff]/;
    function strEscape(str) {
      if (str.length < 5e3 && !strEscapeSequencesRegExp.test(str)) {
        return `"${str}"`;
      }
      return JSON.stringify(str);
    }
    function sort(array, comparator) {
      if (array.length > 200 || comparator) {
        return array.sort(comparator);
      }
      for (let i = 1; i < array.length; i++) {
        const currentValue = array[i];
        let position = i;
        while (position !== 0 && array[position - 1] > currentValue) {
          array[position] = array[position - 1];
          position--;
        }
        array[position] = currentValue;
      }
      return array;
    }
    var typedArrayPrototypeGetSymbolToStringTag = Object.getOwnPropertyDescriptor(
      Object.getPrototypeOf(
        Object.getPrototypeOf(
          new Int8Array()
        )
      ),
      Symbol.toStringTag
    ).get;
    function isTypedArrayWithEntries(value) {
      return typedArrayPrototypeGetSymbolToStringTag.call(value) !== void 0 && value.length !== 0;
    }
    function stringifyTypedArray(array, separator, maximumBreadth) {
      if (array.length < maximumBreadth) {
        maximumBreadth = array.length;
      }
      const whitespace = separator === "," ? "" : " ";
      let res = `"0":${whitespace}${array[0]}`;
      for (let i = 1; i < maximumBreadth; i++) {
        res += `${separator}"${i}":${whitespace}${array[i]}`;
      }
      return res;
    }
    function getCircularValueOption(options) {
      if (hasOwnProperty.call(options, "circularValue")) {
        const circularValue = options.circularValue;
        if (typeof circularValue === "string") {
          return `"${circularValue}"`;
        }
        if (circularValue == null) {
          return circularValue;
        }
        if (circularValue === Error || circularValue === TypeError) {
          return {
            toString() {
              throw new TypeError("Converting circular structure to JSON");
            }
          };
        }
        throw new TypeError('The "circularValue" argument must be of type string or the value null or undefined');
      }
      return '"[Circular]"';
    }
    function getDeterministicOption(options) {
      let value;
      if (hasOwnProperty.call(options, "deterministic")) {
        value = options.deterministic;
        if (typeof value !== "boolean" && typeof value !== "function") {
          throw new TypeError('The "deterministic" argument must be of type boolean or comparator function');
        }
      }
      return value === void 0 ? true : value;
    }
    function getBooleanOption(options, key) {
      let value;
      if (hasOwnProperty.call(options, key)) {
        value = options[key];
        if (typeof value !== "boolean") {
          throw new TypeError(`The "${key}" argument must be of type boolean`);
        }
      }
      return value === void 0 ? true : value;
    }
    function getPositiveIntegerOption(options, key) {
      let value;
      if (hasOwnProperty.call(options, key)) {
        value = options[key];
        if (typeof value !== "number") {
          throw new TypeError(`The "${key}" argument must be of type number`);
        }
        if (!Number.isInteger(value)) {
          throw new TypeError(`The "${key}" argument must be an integer`);
        }
        if (value < 1) {
          throw new RangeError(`The "${key}" argument must be >= 1`);
        }
      }
      return value === void 0 ? Infinity : value;
    }
    function getItemCount(number) {
      if (number === 1) {
        return "1 item";
      }
      return `${number} items`;
    }
    function getUniqueReplacerSet(replacerArray) {
      const replacerSet = /* @__PURE__ */ new Set();
      for (const value of replacerArray) {
        if (typeof value === "string" || typeof value === "number") {
          replacerSet.add(String(value));
        }
      }
      return replacerSet;
    }
    function getStrictOption(options) {
      if (hasOwnProperty.call(options, "strict")) {
        const value = options.strict;
        if (typeof value !== "boolean") {
          throw new TypeError('The "strict" argument must be of type boolean');
        }
        if (value) {
          return (value2) => {
            let message = `Object can not safely be stringified. Received type ${typeof value2}`;
            if (typeof value2 !== "function") message += ` (${value2.toString()})`;
            throw new Error(message);
          };
        }
      }
    }
    function configure(options) {
      options = { ...options };
      const fail = getStrictOption(options);
      if (fail) {
        if (options.bigint === void 0) {
          options.bigint = false;
        }
        if (!("circularValue" in options)) {
          options.circularValue = Error;
        }
      }
      const circularValue = getCircularValueOption(options);
      const bigint = getBooleanOption(options, "bigint");
      const deterministic = getDeterministicOption(options);
      const comparator = typeof deterministic === "function" ? deterministic : void 0;
      const maximumDepth = getPositiveIntegerOption(options, "maximumDepth");
      const maximumBreadth = getPositiveIntegerOption(options, "maximumBreadth");
      function stringifyFnReplacer(key, parent, stack, replacer, spacer, indentation) {
        let value = parent[key];
        if (typeof value === "object" && value !== null && typeof value.toJSON === "function") {
          value = value.toJSON(key);
        }
        value = replacer.call(parent, key, value);
        switch (typeof value) {
          case "string":
            return strEscape(value);
          case "object": {
            if (value === null) {
              return "null";
            }
            if (stack.indexOf(value) !== -1) {
              return circularValue;
            }
            let res = "";
            let join = ",";
            const originalIndentation = indentation;
            if (Array.isArray(value)) {
              if (value.length === 0) {
                return "[]";
              }
              if (maximumDepth < stack.length + 1) {
                return '"[Array]"';
              }
              stack.push(value);
              if (spacer !== "") {
                indentation += spacer;
                res += `
${indentation}`;
                join = `,
${indentation}`;
              }
              const maximumValuesToStringify = Math.min(value.length, maximumBreadth);
              let i = 0;
              for (; i < maximumValuesToStringify - 1; i++) {
                const tmp2 = stringifyFnReplacer(String(i), value, stack, replacer, spacer, indentation);
                res += tmp2 !== void 0 ? tmp2 : "null";
                res += join;
              }
              const tmp = stringifyFnReplacer(String(i), value, stack, replacer, spacer, indentation);
              res += tmp !== void 0 ? tmp : "null";
              if (value.length - 1 > maximumBreadth) {
                const removedKeys = value.length - maximumBreadth - 1;
                res += `${join}"... ${getItemCount(removedKeys)} not stringified"`;
              }
              if (spacer !== "") {
                res += `
${originalIndentation}`;
              }
              stack.pop();
              return `[${res}]`;
            }
            let keys = Object.keys(value);
            const keyLength = keys.length;
            if (keyLength === 0) {
              return "{}";
            }
            if (maximumDepth < stack.length + 1) {
              return '"[Object]"';
            }
            let whitespace = "";
            let separator = "";
            if (spacer !== "") {
              indentation += spacer;
              join = `,
${indentation}`;
              whitespace = " ";
            }
            const maximumPropertiesToStringify = Math.min(keyLength, maximumBreadth);
            if (deterministic && !isTypedArrayWithEntries(value)) {
              keys = sort(keys, comparator);
            }
            stack.push(value);
            for (let i = 0; i < maximumPropertiesToStringify; i++) {
              const key2 = keys[i];
              const tmp = stringifyFnReplacer(key2, value, stack, replacer, spacer, indentation);
              if (tmp !== void 0) {
                res += `${separator}${strEscape(key2)}:${whitespace}${tmp}`;
                separator = join;
              }
            }
            if (keyLength > maximumBreadth) {
              const removedKeys = keyLength - maximumBreadth;
              res += `${separator}"...":${whitespace}"${getItemCount(removedKeys)} not stringified"`;
              separator = join;
            }
            if (spacer !== "" && separator.length > 1) {
              res = `
${indentation}${res}
${originalIndentation}`;
            }
            stack.pop();
            return `{${res}}`;
          }
          case "number":
            return isFinite(value) ? String(value) : fail ? fail(value) : "null";
          case "boolean":
            return value === true ? "true" : "false";
          case "undefined":
            return void 0;
          case "bigint":
            if (bigint) {
              return String(value);
            }
          // fallthrough
          default:
            return fail ? fail(value) : void 0;
        }
      }
      function stringifyArrayReplacer(key, value, stack, replacer, spacer, indentation) {
        if (typeof value === "object" && value !== null && typeof value.toJSON === "function") {
          value = value.toJSON(key);
        }
        switch (typeof value) {
          case "string":
            return strEscape(value);
          case "object": {
            if (value === null) {
              return "null";
            }
            if (stack.indexOf(value) !== -1) {
              return circularValue;
            }
            const originalIndentation = indentation;
            let res = "";
            let join = ",";
            if (Array.isArray(value)) {
              if (value.length === 0) {
                return "[]";
              }
              if (maximumDepth < stack.length + 1) {
                return '"[Array]"';
              }
              stack.push(value);
              if (spacer !== "") {
                indentation += spacer;
                res += `
${indentation}`;
                join = `,
${indentation}`;
              }
              const maximumValuesToStringify = Math.min(value.length, maximumBreadth);
              let i = 0;
              for (; i < maximumValuesToStringify - 1; i++) {
                const tmp2 = stringifyArrayReplacer(String(i), value[i], stack, replacer, spacer, indentation);
                res += tmp2 !== void 0 ? tmp2 : "null";
                res += join;
              }
              const tmp = stringifyArrayReplacer(String(i), value[i], stack, replacer, spacer, indentation);
              res += tmp !== void 0 ? tmp : "null";
              if (value.length - 1 > maximumBreadth) {
                const removedKeys = value.length - maximumBreadth - 1;
                res += `${join}"... ${getItemCount(removedKeys)} not stringified"`;
              }
              if (spacer !== "") {
                res += `
${originalIndentation}`;
              }
              stack.pop();
              return `[${res}]`;
            }
            stack.push(value);
            let whitespace = "";
            if (spacer !== "") {
              indentation += spacer;
              join = `,
${indentation}`;
              whitespace = " ";
            }
            let separator = "";
            for (const key2 of replacer) {
              const tmp = stringifyArrayReplacer(key2, value[key2], stack, replacer, spacer, indentation);
              if (tmp !== void 0) {
                res += `${separator}${strEscape(key2)}:${whitespace}${tmp}`;
                separator = join;
              }
            }
            if (spacer !== "" && separator.length > 1) {
              res = `
${indentation}${res}
${originalIndentation}`;
            }
            stack.pop();
            return `{${res}}`;
          }
          case "number":
            return isFinite(value) ? String(value) : fail ? fail(value) : "null";
          case "boolean":
            return value === true ? "true" : "false";
          case "undefined":
            return void 0;
          case "bigint":
            if (bigint) {
              return String(value);
            }
          // fallthrough
          default:
            return fail ? fail(value) : void 0;
        }
      }
      function stringifyIndent(key, value, stack, spacer, indentation) {
        switch (typeof value) {
          case "string":
            return strEscape(value);
          case "object": {
            if (value === null) {
              return "null";
            }
            if (typeof value.toJSON === "function") {
              value = value.toJSON(key);
              if (typeof value !== "object") {
                return stringifyIndent(key, value, stack, spacer, indentation);
              }
              if (value === null) {
                return "null";
              }
            }
            if (stack.indexOf(value) !== -1) {
              return circularValue;
            }
            const originalIndentation = indentation;
            if (Array.isArray(value)) {
              if (value.length === 0) {
                return "[]";
              }
              if (maximumDepth < stack.length + 1) {
                return '"[Array]"';
              }
              stack.push(value);
              indentation += spacer;
              let res2 = `
${indentation}`;
              const join2 = `,
${indentation}`;
              const maximumValuesToStringify = Math.min(value.length, maximumBreadth);
              let i = 0;
              for (; i < maximumValuesToStringify - 1; i++) {
                const tmp2 = stringifyIndent(String(i), value[i], stack, spacer, indentation);
                res2 += tmp2 !== void 0 ? tmp2 : "null";
                res2 += join2;
              }
              const tmp = stringifyIndent(String(i), value[i], stack, spacer, indentation);
              res2 += tmp !== void 0 ? tmp : "null";
              if (value.length - 1 > maximumBreadth) {
                const removedKeys = value.length - maximumBreadth - 1;
                res2 += `${join2}"... ${getItemCount(removedKeys)} not stringified"`;
              }
              res2 += `
${originalIndentation}`;
              stack.pop();
              return `[${res2}]`;
            }
            let keys = Object.keys(value);
            const keyLength = keys.length;
            if (keyLength === 0) {
              return "{}";
            }
            if (maximumDepth < stack.length + 1) {
              return '"[Object]"';
            }
            indentation += spacer;
            const join = `,
${indentation}`;
            let res = "";
            let separator = "";
            let maximumPropertiesToStringify = Math.min(keyLength, maximumBreadth);
            if (isTypedArrayWithEntries(value)) {
              res += stringifyTypedArray(value, join, maximumBreadth);
              keys = keys.slice(value.length);
              maximumPropertiesToStringify -= value.length;
              separator = join;
            }
            if (deterministic) {
              keys = sort(keys, comparator);
            }
            stack.push(value);
            for (let i = 0; i < maximumPropertiesToStringify; i++) {
              const key2 = keys[i];
              const tmp = stringifyIndent(key2, value[key2], stack, spacer, indentation);
              if (tmp !== void 0) {
                res += `${separator}${strEscape(key2)}: ${tmp}`;
                separator = join;
              }
            }
            if (keyLength > maximumBreadth) {
              const removedKeys = keyLength - maximumBreadth;
              res += `${separator}"...": "${getItemCount(removedKeys)} not stringified"`;
              separator = join;
            }
            if (separator !== "") {
              res = `
${indentation}${res}
${originalIndentation}`;
            }
            stack.pop();
            return `{${res}}`;
          }
          case "number":
            return isFinite(value) ? String(value) : fail ? fail(value) : "null";
          case "boolean":
            return value === true ? "true" : "false";
          case "undefined":
            return void 0;
          case "bigint":
            if (bigint) {
              return String(value);
            }
          // fallthrough
          default:
            return fail ? fail(value) : void 0;
        }
      }
      function stringifySimple(key, value, stack) {
        switch (typeof value) {
          case "string":
            return strEscape(value);
          case "object": {
            if (value === null) {
              return "null";
            }
            if (typeof value.toJSON === "function") {
              value = value.toJSON(key);
              if (typeof value !== "object") {
                return stringifySimple(key, value, stack);
              }
              if (value === null) {
                return "null";
              }
            }
            if (stack.indexOf(value) !== -1) {
              return circularValue;
            }
            let res = "";
            const hasLength = value.length !== void 0;
            if (hasLength && Array.isArray(value)) {
              if (value.length === 0) {
                return "[]";
              }
              if (maximumDepth < stack.length + 1) {
                return '"[Array]"';
              }
              stack.push(value);
              const maximumValuesToStringify = Math.min(value.length, maximumBreadth);
              let i = 0;
              for (; i < maximumValuesToStringify - 1; i++) {
                const tmp2 = stringifySimple(String(i), value[i], stack);
                res += tmp2 !== void 0 ? tmp2 : "null";
                res += ",";
              }
              const tmp = stringifySimple(String(i), value[i], stack);
              res += tmp !== void 0 ? tmp : "null";
              if (value.length - 1 > maximumBreadth) {
                const removedKeys = value.length - maximumBreadth - 1;
                res += `,"... ${getItemCount(removedKeys)} not stringified"`;
              }
              stack.pop();
              return `[${res}]`;
            }
            let keys = Object.keys(value);
            const keyLength = keys.length;
            if (keyLength === 0) {
              return "{}";
            }
            if (maximumDepth < stack.length + 1) {
              return '"[Object]"';
            }
            let separator = "";
            let maximumPropertiesToStringify = Math.min(keyLength, maximumBreadth);
            if (hasLength && isTypedArrayWithEntries(value)) {
              res += stringifyTypedArray(value, ",", maximumBreadth);
              keys = keys.slice(value.length);
              maximumPropertiesToStringify -= value.length;
              separator = ",";
            }
            if (deterministic) {
              keys = sort(keys, comparator);
            }
            stack.push(value);
            for (let i = 0; i < maximumPropertiesToStringify; i++) {
              const key2 = keys[i];
              const tmp = stringifySimple(key2, value[key2], stack);
              if (tmp !== void 0) {
                res += `${separator}${strEscape(key2)}:${tmp}`;
                separator = ",";
              }
            }
            if (keyLength > maximumBreadth) {
              const removedKeys = keyLength - maximumBreadth;
              res += `${separator}"...":"${getItemCount(removedKeys)} not stringified"`;
            }
            stack.pop();
            return `{${res}}`;
          }
          case "number":
            return isFinite(value) ? String(value) : fail ? fail(value) : "null";
          case "boolean":
            return value === true ? "true" : "false";
          case "undefined":
            return void 0;
          case "bigint":
            if (bigint) {
              return String(value);
            }
          // fallthrough
          default:
            return fail ? fail(value) : void 0;
        }
      }
      function stringify2(value, replacer, space) {
        if (arguments.length > 1) {
          let spacer = "";
          if (typeof space === "number") {
            spacer = " ".repeat(Math.min(space, 10));
          } else if (typeof space === "string") {
            spacer = space.slice(0, 10);
          }
          if (replacer != null) {
            if (typeof replacer === "function") {
              return stringifyFnReplacer("", { "": value }, [], replacer, spacer, "");
            }
            if (Array.isArray(replacer)) {
              return stringifyArrayReplacer("", value, [], getUniqueReplacerSet(replacer), spacer, "");
            }
          }
          if (spacer.length !== 0) {
            return stringifyIndent("", value, [], spacer, "");
          }
        }
        return stringifySimple("", value, []);
      }
      return stringify2;
    }
  }
});

// node_modules/logform/json.js
var require_json = __commonJS({
  "node_modules/logform/json.js"(exports2, module2) {
    "use strict";
    var format = require_format();
    var { MESSAGE } = require_triple_beam();
    var stringify = require_safe_stable_stringify();
    function replacer(key, value) {
      if (typeof value === "bigint")
        return value.toString();
      return value;
    }
    module2.exports = format((info, opts) => {
      const jsonStringify = stringify.configure(opts);
      info[MESSAGE] = jsonStringify(info, opts.replacer || replacer, opts.space);
      return info;
    });
  }
});

// node_modules/logform/label.js
var require_label = __commonJS({
  "node_modules/logform/label.js"(exports2, module2) {
    "use strict";
    var format = require_format();
    module2.exports = format((info, opts) => {
      if (opts.message) {
        info.message = `[${opts.label}] ${info.message}`;
        return info;
      }
      info.label = opts.label;
      return info;
    });
  }
});

// node_modules/logform/logstash.js
var require_logstash = __commonJS({
  "node_modules/logform/logstash.js"(exports2, module2) {
    "use strict";
    var format = require_format();
    var { MESSAGE } = require_triple_beam();
    var jsonStringify = require_safe_stable_stringify();
    module2.exports = format((info) => {
      const logstash = {};
      if (info.message) {
        logstash["@message"] = info.message;
        delete info.message;
      }
      if (info.timestamp) {
        logstash["@timestamp"] = info.timestamp;
        delete info.timestamp;
      }
      logstash["@fields"] = info;
      info[MESSAGE] = jsonStringify(logstash);
      return info;
    });
  }
});

// node_modules/logform/metadata.js
var require_metadata = __commonJS({
  "node_modules/logform/metadata.js"(exports2, module2) {
    "use strict";
    var format = require_format();
    function fillExcept(info, fillExceptKeys, metadataKey) {
      const savedKeys = fillExceptKeys.reduce((acc, key) => {
        acc[key] = info[key];
        delete info[key];
        return acc;
      }, {});
      const metadata = Object.keys(info).reduce((acc, key) => {
        acc[key] = info[key];
        delete info[key];
        return acc;
      }, {});
      Object.assign(info, savedKeys, {
        [metadataKey]: metadata
      });
      return info;
    }
    function fillWith(info, fillWithKeys, metadataKey) {
      info[metadataKey] = fillWithKeys.reduce((acc, key) => {
        acc[key] = info[key];
        delete info[key];
        return acc;
      }, {});
      return info;
    }
    module2.exports = format((info, opts = {}) => {
      let metadataKey = "metadata";
      if (opts.key) {
        metadataKey = opts.key;
      }
      let fillExceptKeys = [];
      if (!opts.fillExcept && !opts.fillWith) {
        fillExceptKeys.push("level");
        fillExceptKeys.push("message");
      }
      if (opts.fillExcept) {
        fillExceptKeys = opts.fillExcept;
      }
      if (fillExceptKeys.length > 0) {
        return fillExcept(info, fillExceptKeys, metadataKey);
      }
      if (opts.fillWith) {
        return fillWith(info, opts.fillWith, metadataKey);
      }
      return info;
    });
  }
});

// node_modules/ms/index.js
var require_ms = __commonJS({
  "node_modules/ms/index.js"(exports2, module2) {
    var s = 1e3;
    var m = s * 60;
    var h = m * 60;
    var d = h * 24;
    var w = d * 7;
    var y = d * 365.25;
    module2.exports = function(val, options) {
      options = options || {};
      var type = typeof val;
      if (type === "string" && val.length > 0) {
        return parse(val);
      } else if (type === "number" && isFinite(val)) {
        return options.long ? fmtLong(val) : fmtShort(val);
      }
      throw new Error(
        "val is not a non-empty string or a valid number. val=" + JSON.stringify(val)
      );
    };
    function parse(str) {
      str = String(str);
      if (str.length > 100) {
        return;
      }
      var match = /^(-?(?:\d+)?\.?\d+) *(milliseconds?|msecs?|ms|seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h|days?|d|weeks?|w|years?|yrs?|y)?$/i.exec(
        str
      );
      if (!match) {
        return;
      }
      var n = parseFloat(match[1]);
      var type = (match[2] || "ms").toLowerCase();
      switch (type) {
        case "years":
        case "year":
        case "yrs":
        case "yr":
        case "y":
          return n * y;
        case "weeks":
        case "week":
        case "w":
          return n * w;
        case "days":
        case "day":
        case "d":
          return n * d;
        case "hours":
        case "hour":
        case "hrs":
        case "hr":
        case "h":
          return n * h;
        case "minutes":
        case "minute":
        case "mins":
        case "min":
        case "m":
          return n * m;
        case "seconds":
        case "second":
        case "secs":
        case "sec":
        case "s":
          return n * s;
        case "milliseconds":
        case "millisecond":
        case "msecs":
        case "msec":
        case "ms":
          return n;
        default:
          return void 0;
      }
    }
    function fmtShort(ms) {
      var msAbs = Math.abs(ms);
      if (msAbs >= d) {
        return Math.round(ms / d) + "d";
      }
      if (msAbs >= h) {
        return Math.round(ms / h) + "h";
      }
      if (msAbs >= m) {
        return Math.round(ms / m) + "m";
      }
      if (msAbs >= s) {
        return Math.round(ms / s) + "s";
      }
      return ms + "ms";
    }
    function fmtLong(ms) {
      var msAbs = Math.abs(ms);
      if (msAbs >= d) {
        return plural(ms, msAbs, d, "day");
      }
      if (msAbs >= h) {
        return plural(ms, msAbs, h, "hour");
      }
      if (msAbs >= m) {
        return plural(ms, msAbs, m, "minute");
      }
      if (msAbs >= s) {
        return plural(ms, msAbs, s, "second");
      }
      return ms + " ms";
    }
    function plural(ms, msAbs, n, name) {
      var isPlural = msAbs >= n * 1.5;
      return Math.round(ms / n) + " " + name + (isPlural ? "s" : "");
    }
  }
});

// node_modules/logform/ms.js
var require_ms2 = __commonJS({
  "node_modules/logform/ms.js"(exports2, module2) {
    "use strict";
    var format = require_format();
    var ms = require_ms();
    module2.exports = format((info) => {
      const curr = +/* @__PURE__ */ new Date();
      exports2.diff = curr - (exports2.prevTime || curr);
      exports2.prevTime = curr;
      info.ms = `+${ms(exports2.diff)}`;
      return info;
    });
  }
});

// node_modules/logform/pretty-print.js
var require_pretty_print = __commonJS({
  "node_modules/logform/pretty-print.js"(exports2, module2) {
    "use strict";
    var inspect = require("util").inspect;
    var format = require_format();
    var { LEVEL, MESSAGE, SPLAT } = require_triple_beam();
    module2.exports = format((info, opts = {}) => {
      const stripped = Object.assign({}, info);
      delete stripped[LEVEL];
      delete stripped[MESSAGE];
      delete stripped[SPLAT];
      info[MESSAGE] = inspect(stripped, false, opts.depth || null, opts.colorize);
      return info;
    });
  }
});

// node_modules/logform/printf.js
var require_printf = __commonJS({
  "node_modules/logform/printf.js"(exports2, module2) {
    "use strict";
    var { MESSAGE } = require_triple_beam();
    var Printf = class {
      constructor(templateFn) {
        this.template = templateFn;
      }
      transform(info) {
        info[MESSAGE] = this.template(info);
        return info;
      }
    };
    module2.exports = (opts) => new Printf(opts);
    module2.exports.Printf = module2.exports.Format = Printf;
  }
});

// node_modules/logform/simple.js
var require_simple = __commonJS({
  "node_modules/logform/simple.js"(exports2, module2) {
    "use strict";
    var format = require_format();
    var { MESSAGE } = require_triple_beam();
    var jsonStringify = require_safe_stable_stringify();
    module2.exports = format((info) => {
      const stringifiedRest = jsonStringify(Object.assign({}, info, {
        level: void 0,
        message: void 0,
        splat: void 0
      }));
      const padding = info.padding && info.padding[info.level] || "";
      if (stringifiedRest !== "{}") {
        info[MESSAGE] = `${info.level}:${padding} ${info.message} ${stringifiedRest}`;
      } else {
        info[MESSAGE] = `${info.level}:${padding} ${info.message}`;
      }
      return info;
    });
  }
});

// node_modules/logform/splat.js
var require_splat = __commonJS({
  "node_modules/logform/splat.js"(exports2, module2) {
    "use strict";
    var util = require("util");
    var { SPLAT } = require_triple_beam();
    var formatRegExp = /%[scdjifoO%]/g;
    var escapedPercent = /%%/g;
    var Splatter = class {
      constructor(opts) {
        this.options = opts;
      }
      /**
         * Check to see if tokens <= splat.length, assign { splat, meta } into the
         * `info` accordingly, and write to this instance.
         *
         * @param  {Info} info Logform info message.
         * @param  {String[]} tokens Set of string interpolation tokens.
         * @returns {Info} Modified info message
         * @private
         */
      _splat(info, tokens) {
        const msg = info.message;
        const splat = info[SPLAT] || info.splat || [];
        const percents = msg.match(escapedPercent);
        const escapes = percents && percents.length || 0;
        const expectedSplat = tokens.length - escapes;
        const extraSplat = expectedSplat - splat.length;
        const metas = extraSplat < 0 ? splat.splice(extraSplat, -1 * extraSplat) : [];
        const metalen = metas.length;
        if (metalen) {
          for (let i = 0; i < metalen; i++) {
            Object.assign(info, metas[i]);
          }
        }
        info.message = util.format(msg, ...splat);
        return info;
      }
      /**
        * Transforms the `info` message by using `util.format` to complete
        * any `info.message` provided it has string interpolation tokens.
        * If no tokens exist then `info` is immutable.
        *
        * @param  {Info} info Logform info message.
        * @param  {Object} opts Options for this instance.
        * @returns {Info} Modified info message
        */
      transform(info) {
        const msg = info.message;
        const splat = info[SPLAT] || info.splat;
        if (!splat || !splat.length) {
          return info;
        }
        const tokens = msg && msg.match && msg.match(formatRegExp);
        if (!tokens && (splat || splat.length)) {
          const metas = splat.length > 1 ? splat.splice(0) : splat;
          const metalen = metas.length;
          if (metalen) {
            for (let i = 0; i < metalen; i++) {
              Object.assign(info, metas[i]);
            }
          }
          return info;
        }
        if (tokens) {
          return this._splat(info, tokens);
        }
        return info;
      }
    };
    module2.exports = (opts) => new Splatter(opts);
  }
});

// node_modules/fecha/lib/fecha.umd.js
var require_fecha_umd = __commonJS({
  "node_modules/fecha/lib/fecha.umd.js"(exports2, module2) {
    (function(global2, factory) {
      typeof exports2 === "object" && typeof module2 !== "undefined" ? factory(exports2) : typeof define === "function" && define.amd ? define(["exports"], factory) : factory(global2.fecha = {});
    })(exports2, (function(exports3) {
      "use strict";
      var token = /d{1,4}|M{1,4}|YY(?:YY)?|S{1,3}|Do|ZZ|Z|([HhMsDm])\1?|[aA]|"[^"]*"|'[^']*'/g;
      var twoDigitsOptional = "\\d\\d?";
      var twoDigits = "\\d\\d";
      var threeDigits = "\\d{3}";
      var fourDigits = "\\d{4}";
      var word = "[^\\s]+";
      var literal = /\[([^]*?)\]/gm;
      function shorten(arr, sLen) {
        var newArr = [];
        for (var i = 0, len = arr.length; i < len; i++) {
          newArr.push(arr[i].substr(0, sLen));
        }
        return newArr;
      }
      var monthUpdate = function(arrName) {
        return function(v, i18n) {
          var lowerCaseArr = i18n[arrName].map(function(v2) {
            return v2.toLowerCase();
          });
          var index = lowerCaseArr.indexOf(v.toLowerCase());
          if (index > -1) {
            return index;
          }
          return null;
        };
      };
      function assign(origObj) {
        var args = [];
        for (var _i = 1; _i < arguments.length; _i++) {
          args[_i - 1] = arguments[_i];
        }
        for (var _a = 0, args_1 = args; _a < args_1.length; _a++) {
          var obj = args_1[_a];
          for (var key in obj) {
            origObj[key] = obj[key];
          }
        }
        return origObj;
      }
      var dayNames = [
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday"
      ];
      var monthNames = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December"
      ];
      var monthNamesShort = shorten(monthNames, 3);
      var dayNamesShort = shorten(dayNames, 3);
      var defaultI18n = {
        dayNamesShort,
        dayNames,
        monthNamesShort,
        monthNames,
        amPm: ["am", "pm"],
        DoFn: function(dayOfMonth) {
          return dayOfMonth + ["th", "st", "nd", "rd"][dayOfMonth % 10 > 3 ? 0 : (dayOfMonth - dayOfMonth % 10 !== 10 ? 1 : 0) * dayOfMonth % 10];
        }
      };
      var globalI18n = assign({}, defaultI18n);
      var setGlobalDateI18n = function(i18n) {
        return globalI18n = assign(globalI18n, i18n);
      };
      var regexEscape = function(str) {
        return str.replace(/[|\\{()[^$+*?.-]/g, "\\$&");
      };
      var pad = function(val, len) {
        if (len === void 0) {
          len = 2;
        }
        val = String(val);
        while (val.length < len) {
          val = "0" + val;
        }
        return val;
      };
      var formatFlags = {
        D: function(dateObj) {
          return String(dateObj.getDate());
        },
        DD: function(dateObj) {
          return pad(dateObj.getDate());
        },
        Do: function(dateObj, i18n) {
          return i18n.DoFn(dateObj.getDate());
        },
        d: function(dateObj) {
          return String(dateObj.getDay());
        },
        dd: function(dateObj) {
          return pad(dateObj.getDay());
        },
        ddd: function(dateObj, i18n) {
          return i18n.dayNamesShort[dateObj.getDay()];
        },
        dddd: function(dateObj, i18n) {
          return i18n.dayNames[dateObj.getDay()];
        },
        M: function(dateObj) {
          return String(dateObj.getMonth() + 1);
        },
        MM: function(dateObj) {
          return pad(dateObj.getMonth() + 1);
        },
        MMM: function(dateObj, i18n) {
          return i18n.monthNamesShort[dateObj.getMonth()];
        },
        MMMM: function(dateObj, i18n) {
          return i18n.monthNames[dateObj.getMonth()];
        },
        YY: function(dateObj) {
          return pad(String(dateObj.getFullYear()), 4).substr(2);
        },
        YYYY: function(dateObj) {
          return pad(dateObj.getFullYear(), 4);
        },
        h: function(dateObj) {
          return String(dateObj.getHours() % 12 || 12);
        },
        hh: function(dateObj) {
          return pad(dateObj.getHours() % 12 || 12);
        },
        H: function(dateObj) {
          return String(dateObj.getHours());
        },
        HH: function(dateObj) {
          return pad(dateObj.getHours());
        },
        m: function(dateObj) {
          return String(dateObj.getMinutes());
        },
        mm: function(dateObj) {
          return pad(dateObj.getMinutes());
        },
        s: function(dateObj) {
          return String(dateObj.getSeconds());
        },
        ss: function(dateObj) {
          return pad(dateObj.getSeconds());
        },
        S: function(dateObj) {
          return String(Math.round(dateObj.getMilliseconds() / 100));
        },
        SS: function(dateObj) {
          return pad(Math.round(dateObj.getMilliseconds() / 10), 2);
        },
        SSS: function(dateObj) {
          return pad(dateObj.getMilliseconds(), 3);
        },
        a: function(dateObj, i18n) {
          return dateObj.getHours() < 12 ? i18n.amPm[0] : i18n.amPm[1];
        },
        A: function(dateObj, i18n) {
          return dateObj.getHours() < 12 ? i18n.amPm[0].toUpperCase() : i18n.amPm[1].toUpperCase();
        },
        ZZ: function(dateObj) {
          var offset = dateObj.getTimezoneOffset();
          return (offset > 0 ? "-" : "+") + pad(Math.floor(Math.abs(offset) / 60) * 100 + Math.abs(offset) % 60, 4);
        },
        Z: function(dateObj) {
          var offset = dateObj.getTimezoneOffset();
          return (offset > 0 ? "-" : "+") + pad(Math.floor(Math.abs(offset) / 60), 2) + ":" + pad(Math.abs(offset) % 60, 2);
        }
      };
      var monthParse = function(v) {
        return +v - 1;
      };
      var emptyDigits = [null, twoDigitsOptional];
      var emptyWord = [null, word];
      var amPm = [
        "isPm",
        word,
        function(v, i18n) {
          var val = v.toLowerCase();
          if (val === i18n.amPm[0]) {
            return 0;
          } else if (val === i18n.amPm[1]) {
            return 1;
          }
          return null;
        }
      ];
      var timezoneOffset = [
        "timezoneOffset",
        "[^\\s]*?[\\+\\-]\\d\\d:?\\d\\d|[^\\s]*?Z?",
        function(v) {
          var parts = (v + "").match(/([+-]|\d\d)/gi);
          if (parts) {
            var minutes = +parts[1] * 60 + parseInt(parts[2], 10);
            return parts[0] === "+" ? minutes : -minutes;
          }
          return 0;
        }
      ];
      var parseFlags = {
        D: ["day", twoDigitsOptional],
        DD: ["day", twoDigits],
        Do: ["day", twoDigitsOptional + word, function(v) {
          return parseInt(v, 10);
        }],
        M: ["month", twoDigitsOptional, monthParse],
        MM: ["month", twoDigits, monthParse],
        YY: [
          "year",
          twoDigits,
          function(v) {
            var now = /* @__PURE__ */ new Date();
            var cent = +("" + now.getFullYear()).substr(0, 2);
            return +("" + (+v > 68 ? cent - 1 : cent) + v);
          }
        ],
        h: ["hour", twoDigitsOptional, void 0, "isPm"],
        hh: ["hour", twoDigits, void 0, "isPm"],
        H: ["hour", twoDigitsOptional],
        HH: ["hour", twoDigits],
        m: ["minute", twoDigitsOptional],
        mm: ["minute", twoDigits],
        s: ["second", twoDigitsOptional],
        ss: ["second", twoDigits],
        YYYY: ["year", fourDigits],
        S: ["millisecond", "\\d", function(v) {
          return +v * 100;
        }],
        SS: ["millisecond", twoDigits, function(v) {
          return +v * 10;
        }],
        SSS: ["millisecond", threeDigits],
        d: emptyDigits,
        dd: emptyDigits,
        ddd: emptyWord,
        dddd: emptyWord,
        MMM: ["month", word, monthUpdate("monthNamesShort")],
        MMMM: ["month", word, monthUpdate("monthNames")],
        a: amPm,
        A: amPm,
        ZZ: timezoneOffset,
        Z: timezoneOffset
      };
      var globalMasks = {
        default: "ddd MMM DD YYYY HH:mm:ss",
        shortDate: "M/D/YY",
        mediumDate: "MMM D, YYYY",
        longDate: "MMMM D, YYYY",
        fullDate: "dddd, MMMM D, YYYY",
        isoDate: "YYYY-MM-DD",
        isoDateTime: "YYYY-MM-DDTHH:mm:ssZ",
        shortTime: "HH:mm",
        mediumTime: "HH:mm:ss",
        longTime: "HH:mm:ss.SSS"
      };
      var setGlobalDateMasks = function(masks) {
        return assign(globalMasks, masks);
      };
      var format = function(dateObj, mask, i18n) {
        if (mask === void 0) {
          mask = globalMasks["default"];
        }
        if (i18n === void 0) {
          i18n = {};
        }
        if (typeof dateObj === "number") {
          dateObj = new Date(dateObj);
        }
        if (Object.prototype.toString.call(dateObj) !== "[object Date]" || isNaN(dateObj.getTime())) {
          throw new Error("Invalid Date pass to format");
        }
        mask = globalMasks[mask] || mask;
        var literals = [];
        mask = mask.replace(literal, function($0, $1) {
          literals.push($1);
          return "@@@";
        });
        var combinedI18nSettings = assign(assign({}, globalI18n), i18n);
        mask = mask.replace(token, function($0) {
          return formatFlags[$0](dateObj, combinedI18nSettings);
        });
        return mask.replace(/@@@/g, function() {
          return literals.shift();
        });
      };
      function parse(dateStr, format2, i18n) {
        if (i18n === void 0) {
          i18n = {};
        }
        if (typeof format2 !== "string") {
          throw new Error("Invalid format in fecha parse");
        }
        format2 = globalMasks[format2] || format2;
        if (dateStr.length > 1e3) {
          return null;
        }
        var today = /* @__PURE__ */ new Date();
        var dateInfo = {
          year: today.getFullYear(),
          month: 0,
          day: 1,
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          isPm: null,
          timezoneOffset: null
        };
        var parseInfo = [];
        var literals = [];
        var newFormat = format2.replace(literal, function($0, $1) {
          literals.push(regexEscape($1));
          return "@@@";
        });
        var specifiedFields = {};
        var requiredFields = {};
        newFormat = regexEscape(newFormat).replace(token, function($0) {
          var info = parseFlags[$0];
          var field2 = info[0], regex = info[1], requiredField = info[3];
          if (specifiedFields[field2]) {
            throw new Error("Invalid format. " + field2 + " specified twice in format");
          }
          specifiedFields[field2] = true;
          if (requiredField) {
            requiredFields[requiredField] = true;
          }
          parseInfo.push(info);
          return "(" + regex + ")";
        });
        Object.keys(requiredFields).forEach(function(field2) {
          if (!specifiedFields[field2]) {
            throw new Error("Invalid format. " + field2 + " is required in specified format");
          }
        });
        newFormat = newFormat.replace(/@@@/g, function() {
          return literals.shift();
        });
        var matches = dateStr.match(new RegExp(newFormat, "i"));
        if (!matches) {
          return null;
        }
        var combinedI18nSettings = assign(assign({}, globalI18n), i18n);
        for (var i = 1; i < matches.length; i++) {
          var _a = parseInfo[i - 1], field = _a[0], parser = _a[2];
          var value = parser ? parser(matches[i], combinedI18nSettings) : +matches[i];
          if (value == null) {
            return null;
          }
          dateInfo[field] = value;
        }
        if (dateInfo.isPm === 1 && dateInfo.hour != null && +dateInfo.hour !== 12) {
          dateInfo.hour = +dateInfo.hour + 12;
        } else if (dateInfo.isPm === 0 && +dateInfo.hour === 12) {
          dateInfo.hour = 0;
        }
        var dateTZ;
        if (dateInfo.timezoneOffset == null) {
          dateTZ = new Date(dateInfo.year, dateInfo.month, dateInfo.day, dateInfo.hour, dateInfo.minute, dateInfo.second, dateInfo.millisecond);
          var validateFields = [
            ["month", "getMonth"],
            ["day", "getDate"],
            ["hour", "getHours"],
            ["minute", "getMinutes"],
            ["second", "getSeconds"]
          ];
          for (var i = 0, len = validateFields.length; i < len; i++) {
            if (specifiedFields[validateFields[i][0]] && dateInfo[validateFields[i][0]] !== dateTZ[validateFields[i][1]]()) {
              return null;
            }
          }
        } else {
          dateTZ = new Date(Date.UTC(dateInfo.year, dateInfo.month, dateInfo.day, dateInfo.hour, dateInfo.minute - dateInfo.timezoneOffset, dateInfo.second, dateInfo.millisecond));
          if (dateInfo.month > 11 || dateInfo.month < 0 || dateInfo.day > 31 || dateInfo.day < 1 || dateInfo.hour > 23 || dateInfo.hour < 0 || dateInfo.minute > 59 || dateInfo.minute < 0 || dateInfo.second > 59 || dateInfo.second < 0) {
            return null;
          }
        }
        return dateTZ;
      }
      var fecha = {
        format,
        parse,
        defaultI18n,
        setGlobalDateI18n,
        setGlobalDateMasks
      };
      exports3.assign = assign;
      exports3.default = fecha;
      exports3.format = format;
      exports3.parse = parse;
      exports3.defaultI18n = defaultI18n;
      exports3.setGlobalDateI18n = setGlobalDateI18n;
      exports3.setGlobalDateMasks = setGlobalDateMasks;
      Object.defineProperty(exports3, "__esModule", { value: true });
    }));
  }
});

// node_modules/logform/timestamp.js
var require_timestamp = __commonJS({
  "node_modules/logform/timestamp.js"(exports2, module2) {
    "use strict";
    var fecha = require_fecha_umd();
    var format = require_format();
    module2.exports = format((info, opts = {}) => {
      if (opts.format) {
        info.timestamp = typeof opts.format === "function" ? opts.format() : fecha.format(/* @__PURE__ */ new Date(), opts.format);
      }
      if (!info.timestamp) {
        info.timestamp = (/* @__PURE__ */ new Date()).toISOString();
      }
      if (opts.alias) {
        info[opts.alias] = info.timestamp;
      }
      return info;
    });
  }
});

// node_modules/logform/uncolorize.js
var require_uncolorize = __commonJS({
  "node_modules/logform/uncolorize.js"(exports2, module2) {
    "use strict";
    var colors = require_safe();
    var format = require_format();
    var { MESSAGE } = require_triple_beam();
    module2.exports = format((info, opts) => {
      if (opts.level !== false) {
        info.level = colors.strip(info.level);
      }
      if (opts.message !== false) {
        info.message = colors.strip(String(info.message));
      }
      if (opts.raw !== false && info[MESSAGE]) {
        info[MESSAGE] = colors.strip(String(info[MESSAGE]));
      }
      return info;
    });
  }
});

// node_modules/logform/index.js
var require_logform = __commonJS({
  "node_modules/logform/index.js"(exports2) {
    "use strict";
    var format = exports2.format = require_format();
    exports2.levels = require_levels();
    function exposeFormat(name, requireFormat) {
      Object.defineProperty(format, name, {
        get() {
          return requireFormat();
        },
        configurable: true
      });
    }
    exposeFormat("align", function() {
      return require_align();
    });
    exposeFormat("errors", function() {
      return require_errors();
    });
    exposeFormat("cli", function() {
      return require_cli2();
    });
    exposeFormat("combine", function() {
      return require_combine();
    });
    exposeFormat("colorize", function() {
      return require_colorize();
    });
    exposeFormat("json", function() {
      return require_json();
    });
    exposeFormat("label", function() {
      return require_label();
    });
    exposeFormat("logstash", function() {
      return require_logstash();
    });
    exposeFormat("metadata", function() {
      return require_metadata();
    });
    exposeFormat("ms", function() {
      return require_ms2();
    });
    exposeFormat("padLevels", function() {
      return require_pad_levels();
    });
    exposeFormat("prettyPrint", function() {
      return require_pretty_print();
    });
    exposeFormat("printf", function() {
      return require_printf();
    });
    exposeFormat("simple", function() {
      return require_simple();
    });
    exposeFormat("splat", function() {
      return require_splat();
    });
    exposeFormat("timestamp", function() {
      return require_timestamp();
    });
    exposeFormat("uncolorize", function() {
      return require_uncolorize();
    });
  }
});

// node_modules/winston/lib/winston/common.js
var require_common = __commonJS({
  "node_modules/winston/lib/winston/common.js"(exports2) {
    "use strict";
    var { format } = require("util");
    exports2.warn = {
      deprecated(prop) {
        return () => {
          throw new Error(format("{ %s } was removed in winston@3.0.0.", prop));
        };
      },
      useFormat(prop) {
        return () => {
          throw new Error([
            format("{ %s } was removed in winston@3.0.0.", prop),
            "Use a custom winston.format = winston.format(function) instead."
          ].join("\n"));
        };
      },
      forFunctions(obj, type, props) {
        props.forEach((prop) => {
          obj[prop] = exports2.warn[type](prop);
        });
      },
      forProperties(obj, type, props) {
        props.forEach((prop) => {
          const notice = exports2.warn[type](prop);
          Object.defineProperty(obj, prop, {
            get: notice,
            set: notice
          });
        });
      }
    };
  }
});

// node_modules/winston/package.json
var require_package = __commonJS({
  "node_modules/winston/package.json"(exports2, module2) {
    module2.exports = {
      name: "winston",
      description: "A logger for just about everything.",
      version: "3.19.0",
      author: "Charlie Robbins <charlie.robbins@gmail.com>",
      maintainers: [
        "David Hyde <dabh@alumni.stanford.edu>"
      ],
      repository: {
        type: "git",
        url: "https://github.com/winstonjs/winston.git"
      },
      keywords: [
        "winston",
        "logger",
        "logging",
        "logs",
        "sysadmin",
        "bunyan",
        "pino",
        "loglevel",
        "tools",
        "json",
        "stream"
      ],
      dependencies: {
        "@dabh/diagnostics": "^2.0.8",
        "@colors/colors": "^1.6.0",
        async: "^3.2.3",
        "is-stream": "^2.0.0",
        logform: "^2.7.0",
        "one-time": "^1.0.0",
        "readable-stream": "^3.4.0",
        "safe-stable-stringify": "^2.3.1",
        "stack-trace": "0.0.x",
        "triple-beam": "^1.3.0",
        "winston-transport": "^4.9.0"
      },
      devDependencies: {
        "@babel/cli": "^7.23.9",
        "@babel/core": "^7.24.0",
        "@babel/preset-env": "^7.24.0",
        "@dabh/eslint-config-populist": "^4.4.0",
        "@types/node": "^20.11.24",
        "abstract-winston-transport": "^0.5.1",
        assume: "^2.2.0",
        "cross-spawn-async": "^2.2.5",
        eslint: "^8.57.0",
        hock: "^1.4.1",
        jest: "^29.7.0",
        rimraf: "5.0.10",
        split2: "^4.1.0",
        "std-mocks": "^2.0.0",
        through2: "^4.0.2",
        "winston-compat": "^0.1.5"
      },
      main: "./lib/winston.js",
      browser: "./dist/winston",
      types: "./index.d.ts",
      scripts: {
        lint: "eslint lib/*.js lib/winston/*.js lib/winston/**/*.js --resolve-plugins-relative-to ./node_modules/@dabh/eslint-config-populist",
        test: "jest",
        "test:unit": "jest -c test/jest.config.unit.js",
        "test:integration": "jest -c test/jest.config.integration.js",
        "test:typescript": "npx --package typescript tsc --project test",
        build: "babel lib -d dist",
        prebuild: "rimraf dist",
        prepublishOnly: "npm run build"
      },
      engines: {
        node: ">= 12.0.0"
      },
      license: "MIT"
    };
  }
});

// node_modules/util-deprecate/node.js
var require_node = __commonJS({
  "node_modules/util-deprecate/node.js"(exports2, module2) {
    module2.exports = require("util").deprecate;
  }
});

// node_modules/readable-stream/lib/internal/streams/stream.js
var require_stream = __commonJS({
  "node_modules/readable-stream/lib/internal/streams/stream.js"(exports2, module2) {
    module2.exports = require("stream");
  }
});

// node_modules/readable-stream/lib/internal/streams/destroy.js
var require_destroy = __commonJS({
  "node_modules/readable-stream/lib/internal/streams/destroy.js"(exports2, module2) {
    "use strict";
    function destroy(err, cb) {
      var _this = this;
      var readableDestroyed = this._readableState && this._readableState.destroyed;
      var writableDestroyed = this._writableState && this._writableState.destroyed;
      if (readableDestroyed || writableDestroyed) {
        if (cb) {
          cb(err);
        } else if (err) {
          if (!this._writableState) {
            process.nextTick(emitErrorNT, this, err);
          } else if (!this._writableState.errorEmitted) {
            this._writableState.errorEmitted = true;
            process.nextTick(emitErrorNT, this, err);
          }
        }
        return this;
      }
      if (this._readableState) {
        this._readableState.destroyed = true;
      }
      if (this._writableState) {
        this._writableState.destroyed = true;
      }
      this._destroy(err || null, function(err2) {
        if (!cb && err2) {
          if (!_this._writableState) {
            process.nextTick(emitErrorAndCloseNT, _this, err2);
          } else if (!_this._writableState.errorEmitted) {
            _this._writableState.errorEmitted = true;
            process.nextTick(emitErrorAndCloseNT, _this, err2);
          } else {
            process.nextTick(emitCloseNT, _this);
          }
        } else if (cb) {
          process.nextTick(emitCloseNT, _this);
          cb(err2);
        } else {
          process.nextTick(emitCloseNT, _this);
        }
      });
      return this;
    }
    function emitErrorAndCloseNT(self2, err) {
      emitErrorNT(self2, err);
      emitCloseNT(self2);
    }
    function emitCloseNT(self2) {
      if (self2._writableState && !self2._writableState.emitClose) return;
      if (self2._readableState && !self2._readableState.emitClose) return;
      self2.emit("close");
    }
    function undestroy() {
      if (this._readableState) {
        this._readableState.destroyed = false;
        this._readableState.reading = false;
        this._readableState.ended = false;
        this._readableState.endEmitted = false;
      }
      if (this._writableState) {
        this._writableState.destroyed = false;
        this._writableState.ended = false;
        this._writableState.ending = false;
        this._writableState.finalCalled = false;
        this._writableState.prefinished = false;
        this._writableState.finished = false;
        this._writableState.errorEmitted = false;
      }
    }
    function emitErrorNT(self2, err) {
      self2.emit("error", err);
    }
    function errorOrDestroy(stream, err) {
      var rState = stream._readableState;
      var wState = stream._writableState;
      if (rState && rState.autoDestroy || wState && wState.autoDestroy) stream.destroy(err);
      else stream.emit("error", err);
    }
    module2.exports = {
      destroy,
      undestroy,
      errorOrDestroy
    };
  }
});

// node_modules/readable-stream/errors.js
var require_errors2 = __commonJS({
  "node_modules/readable-stream/errors.js"(exports2, module2) {
    "use strict";
    var codes = {};
    function createErrorType(code, message, Base) {
      if (!Base) {
        Base = Error;
      }
      function getMessage(arg1, arg2, arg3) {
        if (typeof message === "string") {
          return message;
        } else {
          return message(arg1, arg2, arg3);
        }
      }
      class NodeError extends Base {
        constructor(arg1, arg2, arg3) {
          super(getMessage(arg1, arg2, arg3));
        }
      }
      NodeError.prototype.name = Base.name;
      NodeError.prototype.code = code;
      codes[code] = NodeError;
    }
    function oneOf(expected, thing) {
      if (Array.isArray(expected)) {
        const len = expected.length;
        expected = expected.map((i) => String(i));
        if (len > 2) {
          return `one of ${thing} ${expected.slice(0, len - 1).join(", ")}, or ` + expected[len - 1];
        } else if (len === 2) {
          return `one of ${thing} ${expected[0]} or ${expected[1]}`;
        } else {
          return `of ${thing} ${expected[0]}`;
        }
      } else {
        return `of ${thing} ${String(expected)}`;
      }
    }
    function startsWith(str, search, pos) {
      return str.substr(!pos || pos < 0 ? 0 : +pos, search.length) === search;
    }
    function endsWith(str, search, this_len) {
      if (this_len === void 0 || this_len > str.length) {
        this_len = str.length;
      }
      return str.substring(this_len - search.length, this_len) === search;
    }
    function includes(str, search, start) {
      if (typeof start !== "number") {
        start = 0;
      }
      if (start + search.length > str.length) {
        return false;
      } else {
        return str.indexOf(search, start) !== -1;
      }
    }
    createErrorType("ERR_INVALID_OPT_VALUE", function(name, value) {
      return 'The value "' + value + '" is invalid for option "' + name + '"';
    }, TypeError);
    createErrorType("ERR_INVALID_ARG_TYPE", function(name, expected, actual) {
      let determiner;
      if (typeof expected === "string" && startsWith(expected, "not ")) {
        determiner = "must not be";
        expected = expected.replace(/^not /, "");
      } else {
        determiner = "must be";
      }
      let msg;
      if (endsWith(name, " argument")) {
        msg = `The ${name} ${determiner} ${oneOf(expected, "type")}`;
      } else {
        const type = includes(name, ".") ? "property" : "argument";
        msg = `The "${name}" ${type} ${determiner} ${oneOf(expected, "type")}`;
      }
      msg += `. Received type ${typeof actual}`;
      return msg;
    }, TypeError);
    createErrorType("ERR_STREAM_PUSH_AFTER_EOF", "stream.push() after EOF");
    createErrorType("ERR_METHOD_NOT_IMPLEMENTED", function(name) {
      return "The " + name + " method is not implemented";
    });
    createErrorType("ERR_STREAM_PREMATURE_CLOSE", "Premature close");
    createErrorType("ERR_STREAM_DESTROYED", function(name) {
      return "Cannot call " + name + " after a stream was destroyed";
    });
    createErrorType("ERR_MULTIPLE_CALLBACK", "Callback called multiple times");
    createErrorType("ERR_STREAM_CANNOT_PIPE", "Cannot pipe, not readable");
    createErrorType("ERR_STREAM_WRITE_AFTER_END", "write after end");
    createErrorType("ERR_STREAM_NULL_VALUES", "May not write null values to stream", TypeError);
    createErrorType("ERR_UNKNOWN_ENCODING", function(arg) {
      return "Unknown encoding: " + arg;
    }, TypeError);
    createErrorType("ERR_STREAM_UNSHIFT_AFTER_END_EVENT", "stream.unshift() after end event");
    module2.exports.codes = codes;
  }
});

// node_modules/readable-stream/lib/internal/streams/state.js
var require_state = __commonJS({
  "node_modules/readable-stream/lib/internal/streams/state.js"(exports2, module2) {
    "use strict";
    var ERR_INVALID_OPT_VALUE = require_errors2().codes.ERR_INVALID_OPT_VALUE;
    function highWaterMarkFrom(options, isDuplex, duplexKey) {
      return options.highWaterMark != null ? options.highWaterMark : isDuplex ? options[duplexKey] : null;
    }
    function getHighWaterMark(state, options, duplexKey, isDuplex) {
      var hwm = highWaterMarkFrom(options, isDuplex, duplexKey);
      if (hwm != null) {
        if (!(isFinite(hwm) && Math.floor(hwm) === hwm) || hwm < 0) {
          var name = isDuplex ? duplexKey : "highWaterMark";
          throw new ERR_INVALID_OPT_VALUE(name, hwm);
        }
        return Math.floor(hwm);
      }
      return state.objectMode ? 16 : 16 * 1024;
    }
    module2.exports = {
      getHighWaterMark
    };
  }
});

// node_modules/inherits/inherits_browser.js
var require_inherits_browser = __commonJS({
  "node_modules/inherits/inherits_browser.js"(exports2, module2) {
    if (typeof Object.create === "function") {
      module2.exports = function inherits(ctor, superCtor) {
        if (superCtor) {
          ctor.super_ = superCtor;
          ctor.prototype = Object.create(superCtor.prototype, {
            constructor: {
              value: ctor,
              enumerable: false,
              writable: true,
              configurable: true
            }
          });
        }
      };
    } else {
      module2.exports = function inherits(ctor, superCtor) {
        if (superCtor) {
          ctor.super_ = superCtor;
          var TempCtor = function() {
          };
          TempCtor.prototype = superCtor.prototype;
          ctor.prototype = new TempCtor();
          ctor.prototype.constructor = ctor;
        }
      };
    }
  }
});

// node_modules/inherits/inherits.js
var require_inherits = __commonJS({
  "node_modules/inherits/inherits.js"(exports2, module2) {
    try {
      util = require("util");
      if (typeof util.inherits !== "function") throw "";
      module2.exports = util.inherits;
    } catch (e) {
      module2.exports = require_inherits_browser();
    }
    var util;
  }
});

// node_modules/readable-stream/lib/internal/streams/buffer_list.js
var require_buffer_list = __commonJS({
  "node_modules/readable-stream/lib/internal/streams/buffer_list.js"(exports2, module2) {
    "use strict";
    function ownKeys(object, enumerableOnly) {
      var keys = Object.keys(object);
      if (Object.getOwnPropertySymbols) {
        var symbols = Object.getOwnPropertySymbols(object);
        enumerableOnly && (symbols = symbols.filter(function(sym) {
          return Object.getOwnPropertyDescriptor(object, sym).enumerable;
        })), keys.push.apply(keys, symbols);
      }
      return keys;
    }
    function _objectSpread(target) {
      for (var i = 1; i < arguments.length; i++) {
        var source = null != arguments[i] ? arguments[i] : {};
        i % 2 ? ownKeys(Object(source), true).forEach(function(key) {
          _defineProperty(target, key, source[key]);
        }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(target, Object.getOwnPropertyDescriptors(source)) : ownKeys(Object(source)).forEach(function(key) {
          Object.defineProperty(target, key, Object.getOwnPropertyDescriptor(source, key));
        });
      }
      return target;
    }
    function _defineProperty(obj, key, value) {
      key = _toPropertyKey(key);
      if (key in obj) {
        Object.defineProperty(obj, key, { value, enumerable: true, configurable: true, writable: true });
      } else {
        obj[key] = value;
      }
      return obj;
    }
    function _classCallCheck(instance, Constructor) {
      if (!(instance instanceof Constructor)) {
        throw new TypeError("Cannot call a class as a function");
      }
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, _toPropertyKey(descriptor.key), descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      Object.defineProperty(Constructor, "prototype", { writable: false });
      return Constructor;
    }
    function _toPropertyKey(arg) {
      var key = _toPrimitive(arg, "string");
      return typeof key === "symbol" ? key : String(key);
    }
    function _toPrimitive(input, hint) {
      if (typeof input !== "object" || input === null) return input;
      var prim = input[Symbol.toPrimitive];
      if (prim !== void 0) {
        var res = prim.call(input, hint || "default");
        if (typeof res !== "object") return res;
        throw new TypeError("@@toPrimitive must return a primitive value.");
      }
      return (hint === "string" ? String : Number)(input);
    }
    var _require = require("buffer");
    var Buffer2 = _require.Buffer;
    var _require2 = require("util");
    var inspect = _require2.inspect;
    var custom = inspect && inspect.custom || "inspect";
    function copyBuffer(src, target, offset) {
      Buffer2.prototype.copy.call(src, target, offset);
    }
    module2.exports = /* @__PURE__ */ (function() {
      function BufferList() {
        _classCallCheck(this, BufferList);
        this.head = null;
        this.tail = null;
        this.length = 0;
      }
      _createClass(BufferList, [{
        key: "push",
        value: function push(v) {
          var entry = {
            data: v,
            next: null
          };
          if (this.length > 0) this.tail.next = entry;
          else this.head = entry;
          this.tail = entry;
          ++this.length;
        }
      }, {
        key: "unshift",
        value: function unshift(v) {
          var entry = {
            data: v,
            next: this.head
          };
          if (this.length === 0) this.tail = entry;
          this.head = entry;
          ++this.length;
        }
      }, {
        key: "shift",
        value: function shift() {
          if (this.length === 0) return;
          var ret = this.head.data;
          if (this.length === 1) this.head = this.tail = null;
          else this.head = this.head.next;
          --this.length;
          return ret;
        }
      }, {
        key: "clear",
        value: function clear() {
          this.head = this.tail = null;
          this.length = 0;
        }
      }, {
        key: "join",
        value: function join(s) {
          if (this.length === 0) return "";
          var p = this.head;
          var ret = "" + p.data;
          while (p = p.next) ret += s + p.data;
          return ret;
        }
      }, {
        key: "concat",
        value: function concat(n) {
          if (this.length === 0) return Buffer2.alloc(0);
          var ret = Buffer2.allocUnsafe(n >>> 0);
          var p = this.head;
          var i = 0;
          while (p) {
            copyBuffer(p.data, ret, i);
            i += p.data.length;
            p = p.next;
          }
          return ret;
        }
        // Consumes a specified amount of bytes or characters from the buffered data.
      }, {
        key: "consume",
        value: function consume(n, hasStrings) {
          var ret;
          if (n < this.head.data.length) {
            ret = this.head.data.slice(0, n);
            this.head.data = this.head.data.slice(n);
          } else if (n === this.head.data.length) {
            ret = this.shift();
          } else {
            ret = hasStrings ? this._getString(n) : this._getBuffer(n);
          }
          return ret;
        }
      }, {
        key: "first",
        value: function first() {
          return this.head.data;
        }
        // Consumes a specified amount of characters from the buffered data.
      }, {
        key: "_getString",
        value: function _getString(n) {
          var p = this.head;
          var c = 1;
          var ret = p.data;
          n -= ret.length;
          while (p = p.next) {
            var str = p.data;
            var nb = n > str.length ? str.length : n;
            if (nb === str.length) ret += str;
            else ret += str.slice(0, n);
            n -= nb;
            if (n === 0) {
              if (nb === str.length) {
                ++c;
                if (p.next) this.head = p.next;
                else this.head = this.tail = null;
              } else {
                this.head = p;
                p.data = str.slice(nb);
              }
              break;
            }
            ++c;
          }
          this.length -= c;
          return ret;
        }
        // Consumes a specified amount of bytes from the buffered data.
      }, {
        key: "_getBuffer",
        value: function _getBuffer(n) {
          var ret = Buffer2.allocUnsafe(n);
          var p = this.head;
          var c = 1;
          p.data.copy(ret);
          n -= p.data.length;
          while (p = p.next) {
            var buf = p.data;
            var nb = n > buf.length ? buf.length : n;
            buf.copy(ret, ret.length - n, 0, nb);
            n -= nb;
            if (n === 0) {
              if (nb === buf.length) {
                ++c;
                if (p.next) this.head = p.next;
                else this.head = this.tail = null;
              } else {
                this.head = p;
                p.data = buf.slice(nb);
              }
              break;
            }
            ++c;
          }
          this.length -= c;
          return ret;
        }
        // Make sure the linked list only shows the minimal necessary information.
      }, {
        key: custom,
        value: function value(_, options) {
          return inspect(this, _objectSpread(_objectSpread({}, options), {}, {
            // Only inspect one level.
            depth: 0,
            // It should not recurse.
            customInspect: false
          }));
        }
      }]);
      return BufferList;
    })();
  }
});

// node_modules/safe-buffer/index.js
var require_safe_buffer = __commonJS({
  "node_modules/safe-buffer/index.js"(exports2, module2) {
    var buffer = require("buffer");
    var Buffer2 = buffer.Buffer;
    function copyProps(src, dst) {
      for (var key in src) {
        dst[key] = src[key];
      }
    }
    if (Buffer2.from && Buffer2.alloc && Buffer2.allocUnsafe && Buffer2.allocUnsafeSlow) {
      module2.exports = buffer;
    } else {
      copyProps(buffer, exports2);
      exports2.Buffer = SafeBuffer;
    }
    function SafeBuffer(arg, encodingOrOffset, length) {
      return Buffer2(arg, encodingOrOffset, length);
    }
    SafeBuffer.prototype = Object.create(Buffer2.prototype);
    copyProps(Buffer2, SafeBuffer);
    SafeBuffer.from = function(arg, encodingOrOffset, length) {
      if (typeof arg === "number") {
        throw new TypeError("Argument must not be a number");
      }
      return Buffer2(arg, encodingOrOffset, length);
    };
    SafeBuffer.alloc = function(size, fill, encoding) {
      if (typeof size !== "number") {
        throw new TypeError("Argument must be a number");
      }
      var buf = Buffer2(size);
      if (fill !== void 0) {
        if (typeof encoding === "string") {
          buf.fill(fill, encoding);
        } else {
          buf.fill(fill);
        }
      } else {
        buf.fill(0);
      }
      return buf;
    };
    SafeBuffer.allocUnsafe = function(size) {
      if (typeof size !== "number") {
        throw new TypeError("Argument must be a number");
      }
      return Buffer2(size);
    };
    SafeBuffer.allocUnsafeSlow = function(size) {
      if (typeof size !== "number") {
        throw new TypeError("Argument must be a number");
      }
      return buffer.SlowBuffer(size);
    };
  }
});

// node_modules/string_decoder/lib/string_decoder.js
var require_string_decoder = __commonJS({
  "node_modules/string_decoder/lib/string_decoder.js"(exports2) {
    "use strict";
    var Buffer2 = require_safe_buffer().Buffer;
    var isEncoding = Buffer2.isEncoding || function(encoding) {
      encoding = "" + encoding;
      switch (encoding && encoding.toLowerCase()) {
        case "hex":
        case "utf8":
        case "utf-8":
        case "ascii":
        case "binary":
        case "base64":
        case "ucs2":
        case "ucs-2":
        case "utf16le":
        case "utf-16le":
        case "raw":
          return true;
        default:
          return false;
      }
    };
    function _normalizeEncoding(enc) {
      if (!enc) return "utf8";
      var retried;
      while (true) {
        switch (enc) {
          case "utf8":
          case "utf-8":
            return "utf8";
          case "ucs2":
          case "ucs-2":
          case "utf16le":
          case "utf-16le":
            return "utf16le";
          case "latin1":
          case "binary":
            return "latin1";
          case "base64":
          case "ascii":
          case "hex":
            return enc;
          default:
            if (retried) return;
            enc = ("" + enc).toLowerCase();
            retried = true;
        }
      }
    }
    function normalizeEncoding(enc) {
      var nenc = _normalizeEncoding(enc);
      if (typeof nenc !== "string" && (Buffer2.isEncoding === isEncoding || !isEncoding(enc))) throw new Error("Unknown encoding: " + enc);
      return nenc || enc;
    }
    exports2.StringDecoder = StringDecoder;
    function StringDecoder(encoding) {
      this.encoding = normalizeEncoding(encoding);
      var nb;
      switch (this.encoding) {
        case "utf16le":
          this.text = utf16Text;
          this.end = utf16End;
          nb = 4;
          break;
        case "utf8":
          this.fillLast = utf8FillLast;
          nb = 4;
          break;
        case "base64":
          this.text = base64Text;
          this.end = base64End;
          nb = 3;
          break;
        default:
          this.write = simpleWrite;
          this.end = simpleEnd;
          return;
      }
      this.lastNeed = 0;
      this.lastTotal = 0;
      this.lastChar = Buffer2.allocUnsafe(nb);
    }
    StringDecoder.prototype.write = function(buf) {
      if (buf.length === 0) return "";
      var r;
      var i;
      if (this.lastNeed) {
        r = this.fillLast(buf);
        if (r === void 0) return "";
        i = this.lastNeed;
        this.lastNeed = 0;
      } else {
        i = 0;
      }
      if (i < buf.length) return r ? r + this.text(buf, i) : this.text(buf, i);
      return r || "";
    };
    StringDecoder.prototype.end = utf8End;
    StringDecoder.prototype.text = utf8Text;
    StringDecoder.prototype.fillLast = function(buf) {
      if (this.lastNeed <= buf.length) {
        buf.copy(this.lastChar, this.lastTotal - this.lastNeed, 0, this.lastNeed);
        return this.lastChar.toString(this.encoding, 0, this.lastTotal);
      }
      buf.copy(this.lastChar, this.lastTotal - this.lastNeed, 0, buf.length);
      this.lastNeed -= buf.length;
    };
    function utf8CheckByte(byte) {
      if (byte <= 127) return 0;
      else if (byte >> 5 === 6) return 2;
      else if (byte >> 4 === 14) return 3;
      else if (byte >> 3 === 30) return 4;
      return byte >> 6 === 2 ? -1 : -2;
    }
    function utf8CheckIncomplete(self2, buf, i) {
      var j = buf.length - 1;
      if (j < i) return 0;
      var nb = utf8CheckByte(buf[j]);
      if (nb >= 0) {
        if (nb > 0) self2.lastNeed = nb - 1;
        return nb;
      }
      if (--j < i || nb === -2) return 0;
      nb = utf8CheckByte(buf[j]);
      if (nb >= 0) {
        if (nb > 0) self2.lastNeed = nb - 2;
        return nb;
      }
      if (--j < i || nb === -2) return 0;
      nb = utf8CheckByte(buf[j]);
      if (nb >= 0) {
        if (nb > 0) {
          if (nb === 2) nb = 0;
          else self2.lastNeed = nb - 3;
        }
        return nb;
      }
      return 0;
    }
    function utf8CheckExtraBytes(self2, buf, p) {
      if ((buf[0] & 192) !== 128) {
        self2.lastNeed = 0;
        return "\uFFFD";
      }
      if (self2.lastNeed > 1 && buf.length > 1) {
        if ((buf[1] & 192) !== 128) {
          self2.lastNeed = 1;
          return "\uFFFD";
        }
        if (self2.lastNeed > 2 && buf.length > 2) {
          if ((buf[2] & 192) !== 128) {
            self2.lastNeed = 2;
            return "\uFFFD";
          }
        }
      }
    }
    function utf8FillLast(buf) {
      var p = this.lastTotal - this.lastNeed;
      var r = utf8CheckExtraBytes(this, buf, p);
      if (r !== void 0) return r;
      if (this.lastNeed <= buf.length) {
        buf.copy(this.lastChar, p, 0, this.lastNeed);
        return this.lastChar.toString(this.encoding, 0, this.lastTotal);
      }
      buf.copy(this.lastChar, p, 0, buf.length);
      this.lastNeed -= buf.length;
    }
    function utf8Text(buf, i) {
      var total = utf8CheckIncomplete(this, buf, i);
      if (!this.lastNeed) return buf.toString("utf8", i);
      this.lastTotal = total;
      var end = buf.length - (total - this.lastNeed);
      buf.copy(this.lastChar, 0, end);
      return buf.toString("utf8", i, end);
    }
    function utf8End(buf) {
      var r = buf && buf.length ? this.write(buf) : "";
      if (this.lastNeed) return r + "\uFFFD";
      return r;
    }
    function utf16Text(buf, i) {
      if ((buf.length - i) % 2 === 0) {
        var r = buf.toString("utf16le", i);
        if (r) {
          var c = r.charCodeAt(r.length - 1);
          if (c >= 55296 && c <= 56319) {
            this.lastNeed = 2;
            this.lastTotal = 4;
            this.lastChar[0] = buf[buf.length - 2];
            this.lastChar[1] = buf[buf.length - 1];
            return r.slice(0, -1);
          }
        }
        return r;
      }
      this.lastNeed = 1;
      this.lastTotal = 2;
      this.lastChar[0] = buf[buf.length - 1];
      return buf.toString("utf16le", i, buf.length - 1);
    }
    function utf16End(buf) {
      var r = buf && buf.length ? this.write(buf) : "";
      if (this.lastNeed) {
        var end = this.lastTotal - this.lastNeed;
        return r + this.lastChar.toString("utf16le", 0, end);
      }
      return r;
    }
    function base64Text(buf, i) {
      var n = (buf.length - i) % 3;
      if (n === 0) return buf.toString("base64", i);
      this.lastNeed = 3 - n;
      this.lastTotal = 3;
      if (n === 1) {
        this.lastChar[0] = buf[buf.length - 1];
      } else {
        this.lastChar[0] = buf[buf.length - 2];
        this.lastChar[1] = buf[buf.length - 1];
      }
      return buf.toString("base64", i, buf.length - n);
    }
    function base64End(buf) {
      var r = buf && buf.length ? this.write(buf) : "";
      if (this.lastNeed) return r + this.lastChar.toString("base64", 0, 3 - this.lastNeed);
      return r;
    }
    function simpleWrite(buf) {
      return buf.toString(this.encoding);
    }
    function simpleEnd(buf) {
      return buf && buf.length ? this.write(buf) : "";
    }
  }
});

// node_modules/readable-stream/lib/internal/streams/end-of-stream.js
var require_end_of_stream = __commonJS({
  "node_modules/readable-stream/lib/internal/streams/end-of-stream.js"(exports2, module2) {
    "use strict";
    var ERR_STREAM_PREMATURE_CLOSE = require_errors2().codes.ERR_STREAM_PREMATURE_CLOSE;
    function once(callback) {
      var called = false;
      return function() {
        if (called) return;
        called = true;
        for (var _len = arguments.length, args = new Array(_len), _key = 0; _key < _len; _key++) {
          args[_key] = arguments[_key];
        }
        callback.apply(this, args);
      };
    }
    function noop() {
    }
    function isRequest(stream) {
      return stream.setHeader && typeof stream.abort === "function";
    }
    function eos(stream, opts, callback) {
      if (typeof opts === "function") return eos(stream, null, opts);
      if (!opts) opts = {};
      callback = once(callback || noop);
      var readable = opts.readable || opts.readable !== false && stream.readable;
      var writable = opts.writable || opts.writable !== false && stream.writable;
      var onlegacyfinish = function onlegacyfinish2() {
        if (!stream.writable) onfinish();
      };
      var writableEnded = stream._writableState && stream._writableState.finished;
      var onfinish = function onfinish2() {
        writable = false;
        writableEnded = true;
        if (!readable) callback.call(stream);
      };
      var readableEnded = stream._readableState && stream._readableState.endEmitted;
      var onend = function onend2() {
        readable = false;
        readableEnded = true;
        if (!writable) callback.call(stream);
      };
      var onerror = function onerror2(err) {
        callback.call(stream, err);
      };
      var onclose = function onclose2() {
        var err;
        if (readable && !readableEnded) {
          if (!stream._readableState || !stream._readableState.ended) err = new ERR_STREAM_PREMATURE_CLOSE();
          return callback.call(stream, err);
        }
        if (writable && !writableEnded) {
          if (!stream._writableState || !stream._writableState.ended) err = new ERR_STREAM_PREMATURE_CLOSE();
          return callback.call(stream, err);
        }
      };
      var onrequest = function onrequest2() {
        stream.req.on("finish", onfinish);
      };
      if (isRequest(stream)) {
        stream.on("complete", onfinish);
        stream.on("abort", onclose);
        if (stream.req) onrequest();
        else stream.on("request", onrequest);
      } else if (writable && !stream._writableState) {
        stream.on("end", onlegacyfinish);
        stream.on("close", onlegacyfinish);
      }
      stream.on("end", onend);
      stream.on("finish", onfinish);
      if (opts.error !== false) stream.on("error", onerror);
      stream.on("close", onclose);
      return function() {
        stream.removeListener("complete", onfinish);
        stream.removeListener("abort", onclose);
        stream.removeListener("request", onrequest);
        if (stream.req) stream.req.removeListener("finish", onfinish);
        stream.removeListener("end", onlegacyfinish);
        stream.removeListener("close", onlegacyfinish);
        stream.removeListener("finish", onfinish);
        stream.removeListener("end", onend);
        stream.removeListener("error", onerror);
        stream.removeListener("close", onclose);
      };
    }
    module2.exports = eos;
  }
});

// node_modules/readable-stream/lib/internal/streams/async_iterator.js
var require_async_iterator = __commonJS({
  "node_modules/readable-stream/lib/internal/streams/async_iterator.js"(exports2, module2) {
    "use strict";
    var _Object$setPrototypeO;
    function _defineProperty(obj, key, value) {
      key = _toPropertyKey(key);
      if (key in obj) {
        Object.defineProperty(obj, key, { value, enumerable: true, configurable: true, writable: true });
      } else {
        obj[key] = value;
      }
      return obj;
    }
    function _toPropertyKey(arg) {
      var key = _toPrimitive(arg, "string");
      return typeof key === "symbol" ? key : String(key);
    }
    function _toPrimitive(input, hint) {
      if (typeof input !== "object" || input === null) return input;
      var prim = input[Symbol.toPrimitive];
      if (prim !== void 0) {
        var res = prim.call(input, hint || "default");
        if (typeof res !== "object") return res;
        throw new TypeError("@@toPrimitive must return a primitive value.");
      }
      return (hint === "string" ? String : Number)(input);
    }
    var finished = require_end_of_stream();
    var kLastResolve = /* @__PURE__ */ Symbol("lastResolve");
    var kLastReject = /* @__PURE__ */ Symbol("lastReject");
    var kError = /* @__PURE__ */ Symbol("error");
    var kEnded = /* @__PURE__ */ Symbol("ended");
    var kLastPromise = /* @__PURE__ */ Symbol("lastPromise");
    var kHandlePromise = /* @__PURE__ */ Symbol("handlePromise");
    var kStream = /* @__PURE__ */ Symbol("stream");
    function createIterResult(value, done) {
      return {
        value,
        done
      };
    }
    function readAndResolve(iter) {
      var resolve = iter[kLastResolve];
      if (resolve !== null) {
        var data = iter[kStream].read();
        if (data !== null) {
          iter[kLastPromise] = null;
          iter[kLastResolve] = null;
          iter[kLastReject] = null;
          resolve(createIterResult(data, false));
        }
      }
    }
    function onReadable(iter) {
      process.nextTick(readAndResolve, iter);
    }
    function wrapForNext(lastPromise, iter) {
      return function(resolve, reject) {
        lastPromise.then(function() {
          if (iter[kEnded]) {
            resolve(createIterResult(void 0, true));
            return;
          }
          iter[kHandlePromise](resolve, reject);
        }, reject);
      };
    }
    var AsyncIteratorPrototype = Object.getPrototypeOf(function() {
    });
    var ReadableStreamAsyncIteratorPrototype = Object.setPrototypeOf((_Object$setPrototypeO = {
      get stream() {
        return this[kStream];
      },
      next: function next() {
        var _this = this;
        var error = this[kError];
        if (error !== null) {
          return Promise.reject(error);
        }
        if (this[kEnded]) {
          return Promise.resolve(createIterResult(void 0, true));
        }
        if (this[kStream].destroyed) {
          return new Promise(function(resolve, reject) {
            process.nextTick(function() {
              if (_this[kError]) {
                reject(_this[kError]);
              } else {
                resolve(createIterResult(void 0, true));
              }
            });
          });
        }
        var lastPromise = this[kLastPromise];
        var promise;
        if (lastPromise) {
          promise = new Promise(wrapForNext(lastPromise, this));
        } else {
          var data = this[kStream].read();
          if (data !== null) {
            return Promise.resolve(createIterResult(data, false));
          }
          promise = new Promise(this[kHandlePromise]);
        }
        this[kLastPromise] = promise;
        return promise;
      }
    }, _defineProperty(_Object$setPrototypeO, Symbol.asyncIterator, function() {
      return this;
    }), _defineProperty(_Object$setPrototypeO, "return", function _return() {
      var _this2 = this;
      return new Promise(function(resolve, reject) {
        _this2[kStream].destroy(null, function(err) {
          if (err) {
            reject(err);
            return;
          }
          resolve(createIterResult(void 0, true));
        });
      });
    }), _Object$setPrototypeO), AsyncIteratorPrototype);
    var createReadableStreamAsyncIterator = function createReadableStreamAsyncIterator2(stream) {
      var _Object$create;
      var iterator = Object.create(ReadableStreamAsyncIteratorPrototype, (_Object$create = {}, _defineProperty(_Object$create, kStream, {
        value: stream,
        writable: true
      }), _defineProperty(_Object$create, kLastResolve, {
        value: null,
        writable: true
      }), _defineProperty(_Object$create, kLastReject, {
        value: null,
        writable: true
      }), _defineProperty(_Object$create, kError, {
        value: null,
        writable: true
      }), _defineProperty(_Object$create, kEnded, {
        value: stream._readableState.endEmitted,
        writable: true
      }), _defineProperty(_Object$create, kHandlePromise, {
        value: function value(resolve, reject) {
          var data = iterator[kStream].read();
          if (data) {
            iterator[kLastPromise] = null;
            iterator[kLastResolve] = null;
            iterator[kLastReject] = null;
            resolve(createIterResult(data, false));
          } else {
            iterator[kLastResolve] = resolve;
            iterator[kLastReject] = reject;
          }
        },
        writable: true
      }), _Object$create));
      iterator[kLastPromise] = null;
      finished(stream, function(err) {
        if (err && err.code !== "ERR_STREAM_PREMATURE_CLOSE") {
          var reject = iterator[kLastReject];
          if (reject !== null) {
            iterator[kLastPromise] = null;
            iterator[kLastResolve] = null;
            iterator[kLastReject] = null;
            reject(err);
          }
          iterator[kError] = err;
          return;
        }
        var resolve = iterator[kLastResolve];
        if (resolve !== null) {
          iterator[kLastPromise] = null;
          iterator[kLastResolve] = null;
          iterator[kLastReject] = null;
          resolve(createIterResult(void 0, true));
        }
        iterator[kEnded] = true;
      });
      stream.on("readable", onReadable.bind(null, iterator));
      return iterator;
    };
    module2.exports = createReadableStreamAsyncIterator;
  }
});

// node_modules/readable-stream/lib/internal/streams/from.js
var require_from = __commonJS({
  "node_modules/readable-stream/lib/internal/streams/from.js"(exports2, module2) {
    "use strict";
    function asyncGeneratorStep(gen, resolve, reject, _next, _throw, key, arg) {
      try {
        var info = gen[key](arg);
        var value = info.value;
      } catch (error) {
        reject(error);
        return;
      }
      if (info.done) {
        resolve(value);
      } else {
        Promise.resolve(value).then(_next, _throw);
      }
    }
    function _asyncToGenerator(fn) {
      return function() {
        var self2 = this, args = arguments;
        return new Promise(function(resolve, reject) {
          var gen = fn.apply(self2, args);
          function _next(value) {
            asyncGeneratorStep(gen, resolve, reject, _next, _throw, "next", value);
          }
          function _throw(err) {
            asyncGeneratorStep(gen, resolve, reject, _next, _throw, "throw", err);
          }
          _next(void 0);
        });
      };
    }
    function ownKeys(object, enumerableOnly) {
      var keys = Object.keys(object);
      if (Object.getOwnPropertySymbols) {
        var symbols = Object.getOwnPropertySymbols(object);
        enumerableOnly && (symbols = symbols.filter(function(sym) {
          return Object.getOwnPropertyDescriptor(object, sym).enumerable;
        })), keys.push.apply(keys, symbols);
      }
      return keys;
    }
    function _objectSpread(target) {
      for (var i = 1; i < arguments.length; i++) {
        var source = null != arguments[i] ? arguments[i] : {};
        i % 2 ? ownKeys(Object(source), true).forEach(function(key) {
          _defineProperty(target, key, source[key]);
        }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(target, Object.getOwnPropertyDescriptors(source)) : ownKeys(Object(source)).forEach(function(key) {
          Object.defineProperty(target, key, Object.getOwnPropertyDescriptor(source, key));
        });
      }
      return target;
    }
    function _defineProperty(obj, key, value) {
      key = _toPropertyKey(key);
      if (key in obj) {
        Object.defineProperty(obj, key, { value, enumerable: true, configurable: true, writable: true });
      } else {
        obj[key] = value;
      }
      return obj;
    }
    function _toPropertyKey(arg) {
      var key = _toPrimitive(arg, "string");
      return typeof key === "symbol" ? key : String(key);
    }
    function _toPrimitive(input, hint) {
      if (typeof input !== "object" || input === null) return input;
      var prim = input[Symbol.toPrimitive];
      if (prim !== void 0) {
        var res = prim.call(input, hint || "default");
        if (typeof res !== "object") return res;
        throw new TypeError("@@toPrimitive must return a primitive value.");
      }
      return (hint === "string" ? String : Number)(input);
    }
    var ERR_INVALID_ARG_TYPE = require_errors2().codes.ERR_INVALID_ARG_TYPE;
    function from(Readable, iterable, opts) {
      var iterator;
      if (iterable && typeof iterable.next === "function") {
        iterator = iterable;
      } else if (iterable && iterable[Symbol.asyncIterator]) iterator = iterable[Symbol.asyncIterator]();
      else if (iterable && iterable[Symbol.iterator]) iterator = iterable[Symbol.iterator]();
      else throw new ERR_INVALID_ARG_TYPE("iterable", ["Iterable"], iterable);
      var readable = new Readable(_objectSpread({
        objectMode: true
      }, opts));
      var reading = false;
      readable._read = function() {
        if (!reading) {
          reading = true;
          next();
        }
      };
      function next() {
        return _next2.apply(this, arguments);
      }
      function _next2() {
        _next2 = _asyncToGenerator(function* () {
          try {
            var _yield$iterator$next = yield iterator.next(), value = _yield$iterator$next.value, done = _yield$iterator$next.done;
            if (done) {
              readable.push(null);
            } else if (readable.push(yield value)) {
              next();
            } else {
              reading = false;
            }
          } catch (err) {
            readable.destroy(err);
          }
        });
        return _next2.apply(this, arguments);
      }
      return readable;
    }
    module2.exports = from;
  }
});

// node_modules/readable-stream/lib/_stream_readable.js
var require_stream_readable = __commonJS({
  "node_modules/readable-stream/lib/_stream_readable.js"(exports2, module2) {
    "use strict";
    module2.exports = Readable;
    var Duplex;
    Readable.ReadableState = ReadableState;
    var EE = require("events").EventEmitter;
    var EElistenerCount = function EElistenerCount2(emitter, type) {
      return emitter.listeners(type).length;
    };
    var Stream = require_stream();
    var Buffer2 = require("buffer").Buffer;
    var OurUint8Array = (typeof global !== "undefined" ? global : typeof window !== "undefined" ? window : typeof self !== "undefined" ? self : {}).Uint8Array || function() {
    };
    function _uint8ArrayToBuffer(chunk) {
      return Buffer2.from(chunk);
    }
    function _isUint8Array(obj) {
      return Buffer2.isBuffer(obj) || obj instanceof OurUint8Array;
    }
    var debugUtil = require("util");
    var debug;
    if (debugUtil && debugUtil.debuglog) {
      debug = debugUtil.debuglog("stream");
    } else {
      debug = function debug2() {
      };
    }
    var BufferList = require_buffer_list();
    var destroyImpl = require_destroy();
    var _require = require_state();
    var getHighWaterMark = _require.getHighWaterMark;
    var _require$codes = require_errors2().codes;
    var ERR_INVALID_ARG_TYPE = _require$codes.ERR_INVALID_ARG_TYPE;
    var ERR_STREAM_PUSH_AFTER_EOF = _require$codes.ERR_STREAM_PUSH_AFTER_EOF;
    var ERR_METHOD_NOT_IMPLEMENTED = _require$codes.ERR_METHOD_NOT_IMPLEMENTED;
    var ERR_STREAM_UNSHIFT_AFTER_END_EVENT = _require$codes.ERR_STREAM_UNSHIFT_AFTER_END_EVENT;
    var StringDecoder;
    var createReadableStreamAsyncIterator;
    var from;
    require_inherits()(Readable, Stream);
    var errorOrDestroy = destroyImpl.errorOrDestroy;
    var kProxyEvents = ["error", "close", "destroy", "pause", "resume"];
    function prependListener(emitter, event, fn) {
      if (typeof emitter.prependListener === "function") return emitter.prependListener(event, fn);
      if (!emitter._events || !emitter._events[event]) emitter.on(event, fn);
      else if (Array.isArray(emitter._events[event])) emitter._events[event].unshift(fn);
      else emitter._events[event] = [fn, emitter._events[event]];
    }
    function ReadableState(options, stream, isDuplex) {
      Duplex = Duplex || require_stream_duplex();
      options = options || {};
      if (typeof isDuplex !== "boolean") isDuplex = stream instanceof Duplex;
      this.objectMode = !!options.objectMode;
      if (isDuplex) this.objectMode = this.objectMode || !!options.readableObjectMode;
      this.highWaterMark = getHighWaterMark(this, options, "readableHighWaterMark", isDuplex);
      this.buffer = new BufferList();
      this.length = 0;
      this.pipes = null;
      this.pipesCount = 0;
      this.flowing = null;
      this.ended = false;
      this.endEmitted = false;
      this.reading = false;
      this.sync = true;
      this.needReadable = false;
      this.emittedReadable = false;
      this.readableListening = false;
      this.resumeScheduled = false;
      this.paused = true;
      this.emitClose = options.emitClose !== false;
      this.autoDestroy = !!options.autoDestroy;
      this.destroyed = false;
      this.defaultEncoding = options.defaultEncoding || "utf8";
      this.awaitDrain = 0;
      this.readingMore = false;
      this.decoder = null;
      this.encoding = null;
      if (options.encoding) {
        if (!StringDecoder) StringDecoder = require_string_decoder().StringDecoder;
        this.decoder = new StringDecoder(options.encoding);
        this.encoding = options.encoding;
      }
    }
    function Readable(options) {
      Duplex = Duplex || require_stream_duplex();
      if (!(this instanceof Readable)) return new Readable(options);
      var isDuplex = this instanceof Duplex;
      this._readableState = new ReadableState(options, this, isDuplex);
      this.readable = true;
      if (options) {
        if (typeof options.read === "function") this._read = options.read;
        if (typeof options.destroy === "function") this._destroy = options.destroy;
      }
      Stream.call(this);
    }
    Object.defineProperty(Readable.prototype, "destroyed", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        if (this._readableState === void 0) {
          return false;
        }
        return this._readableState.destroyed;
      },
      set: function set(value) {
        if (!this._readableState) {
          return;
        }
        this._readableState.destroyed = value;
      }
    });
    Readable.prototype.destroy = destroyImpl.destroy;
    Readable.prototype._undestroy = destroyImpl.undestroy;
    Readable.prototype._destroy = function(err, cb) {
      cb(err);
    };
    Readable.prototype.push = function(chunk, encoding) {
      var state = this._readableState;
      var skipChunkCheck;
      if (!state.objectMode) {
        if (typeof chunk === "string") {
          encoding = encoding || state.defaultEncoding;
          if (encoding !== state.encoding) {
            chunk = Buffer2.from(chunk, encoding);
            encoding = "";
          }
          skipChunkCheck = true;
        }
      } else {
        skipChunkCheck = true;
      }
      return readableAddChunk(this, chunk, encoding, false, skipChunkCheck);
    };
    Readable.prototype.unshift = function(chunk) {
      return readableAddChunk(this, chunk, null, true, false);
    };
    function readableAddChunk(stream, chunk, encoding, addToFront, skipChunkCheck) {
      debug("readableAddChunk", chunk);
      var state = stream._readableState;
      if (chunk === null) {
        state.reading = false;
        onEofChunk(stream, state);
      } else {
        var er;
        if (!skipChunkCheck) er = chunkInvalid(state, chunk);
        if (er) {
          errorOrDestroy(stream, er);
        } else if (state.objectMode || chunk && chunk.length > 0) {
          if (typeof chunk !== "string" && !state.objectMode && Object.getPrototypeOf(chunk) !== Buffer2.prototype) {
            chunk = _uint8ArrayToBuffer(chunk);
          }
          if (addToFront) {
            if (state.endEmitted) errorOrDestroy(stream, new ERR_STREAM_UNSHIFT_AFTER_END_EVENT());
            else addChunk(stream, state, chunk, true);
          } else if (state.ended) {
            errorOrDestroy(stream, new ERR_STREAM_PUSH_AFTER_EOF());
          } else if (state.destroyed) {
            return false;
          } else {
            state.reading = false;
            if (state.decoder && !encoding) {
              chunk = state.decoder.write(chunk);
              if (state.objectMode || chunk.length !== 0) addChunk(stream, state, chunk, false);
              else maybeReadMore(stream, state);
            } else {
              addChunk(stream, state, chunk, false);
            }
          }
        } else if (!addToFront) {
          state.reading = false;
          maybeReadMore(stream, state);
        }
      }
      return !state.ended && (state.length < state.highWaterMark || state.length === 0);
    }
    function addChunk(stream, state, chunk, addToFront) {
      if (state.flowing && state.length === 0 && !state.sync) {
        state.awaitDrain = 0;
        stream.emit("data", chunk);
      } else {
        state.length += state.objectMode ? 1 : chunk.length;
        if (addToFront) state.buffer.unshift(chunk);
        else state.buffer.push(chunk);
        if (state.needReadable) emitReadable(stream);
      }
      maybeReadMore(stream, state);
    }
    function chunkInvalid(state, chunk) {
      var er;
      if (!_isUint8Array(chunk) && typeof chunk !== "string" && chunk !== void 0 && !state.objectMode) {
        er = new ERR_INVALID_ARG_TYPE("chunk", ["string", "Buffer", "Uint8Array"], chunk);
      }
      return er;
    }
    Readable.prototype.isPaused = function() {
      return this._readableState.flowing === false;
    };
    Readable.prototype.setEncoding = function(enc) {
      if (!StringDecoder) StringDecoder = require_string_decoder().StringDecoder;
      var decoder = new StringDecoder(enc);
      this._readableState.decoder = decoder;
      this._readableState.encoding = this._readableState.decoder.encoding;
      var p = this._readableState.buffer.head;
      var content = "";
      while (p !== null) {
        content += decoder.write(p.data);
        p = p.next;
      }
      this._readableState.buffer.clear();
      if (content !== "") this._readableState.buffer.push(content);
      this._readableState.length = content.length;
      return this;
    };
    var MAX_HWM = 1073741824;
    function computeNewHighWaterMark(n) {
      if (n >= MAX_HWM) {
        n = MAX_HWM;
      } else {
        n--;
        n |= n >>> 1;
        n |= n >>> 2;
        n |= n >>> 4;
        n |= n >>> 8;
        n |= n >>> 16;
        n++;
      }
      return n;
    }
    function howMuchToRead(n, state) {
      if (n <= 0 || state.length === 0 && state.ended) return 0;
      if (state.objectMode) return 1;
      if (n !== n) {
        if (state.flowing && state.length) return state.buffer.head.data.length;
        else return state.length;
      }
      if (n > state.highWaterMark) state.highWaterMark = computeNewHighWaterMark(n);
      if (n <= state.length) return n;
      if (!state.ended) {
        state.needReadable = true;
        return 0;
      }
      return state.length;
    }
    Readable.prototype.read = function(n) {
      debug("read", n);
      n = parseInt(n, 10);
      var state = this._readableState;
      var nOrig = n;
      if (n !== 0) state.emittedReadable = false;
      if (n === 0 && state.needReadable && ((state.highWaterMark !== 0 ? state.length >= state.highWaterMark : state.length > 0) || state.ended)) {
        debug("read: emitReadable", state.length, state.ended);
        if (state.length === 0 && state.ended) endReadable(this);
        else emitReadable(this);
        return null;
      }
      n = howMuchToRead(n, state);
      if (n === 0 && state.ended) {
        if (state.length === 0) endReadable(this);
        return null;
      }
      var doRead = state.needReadable;
      debug("need readable", doRead);
      if (state.length === 0 || state.length - n < state.highWaterMark) {
        doRead = true;
        debug("length less than watermark", doRead);
      }
      if (state.ended || state.reading) {
        doRead = false;
        debug("reading or ended", doRead);
      } else if (doRead) {
        debug("do read");
        state.reading = true;
        state.sync = true;
        if (state.length === 0) state.needReadable = true;
        this._read(state.highWaterMark);
        state.sync = false;
        if (!state.reading) n = howMuchToRead(nOrig, state);
      }
      var ret;
      if (n > 0) ret = fromList(n, state);
      else ret = null;
      if (ret === null) {
        state.needReadable = state.length <= state.highWaterMark;
        n = 0;
      } else {
        state.length -= n;
        state.awaitDrain = 0;
      }
      if (state.length === 0) {
        if (!state.ended) state.needReadable = true;
        if (nOrig !== n && state.ended) endReadable(this);
      }
      if (ret !== null) this.emit("data", ret);
      return ret;
    };
    function onEofChunk(stream, state) {
      debug("onEofChunk");
      if (state.ended) return;
      if (state.decoder) {
        var chunk = state.decoder.end();
        if (chunk && chunk.length) {
          state.buffer.push(chunk);
          state.length += state.objectMode ? 1 : chunk.length;
        }
      }
      state.ended = true;
      if (state.sync) {
        emitReadable(stream);
      } else {
        state.needReadable = false;
        if (!state.emittedReadable) {
          state.emittedReadable = true;
          emitReadable_(stream);
        }
      }
    }
    function emitReadable(stream) {
      var state = stream._readableState;
      debug("emitReadable", state.needReadable, state.emittedReadable);
      state.needReadable = false;
      if (!state.emittedReadable) {
        debug("emitReadable", state.flowing);
        state.emittedReadable = true;
        process.nextTick(emitReadable_, stream);
      }
    }
    function emitReadable_(stream) {
      var state = stream._readableState;
      debug("emitReadable_", state.destroyed, state.length, state.ended);
      if (!state.destroyed && (state.length || state.ended)) {
        stream.emit("readable");
        state.emittedReadable = false;
      }
      state.needReadable = !state.flowing && !state.ended && state.length <= state.highWaterMark;
      flow(stream);
    }
    function maybeReadMore(stream, state) {
      if (!state.readingMore) {
        state.readingMore = true;
        process.nextTick(maybeReadMore_, stream, state);
      }
    }
    function maybeReadMore_(stream, state) {
      while (!state.reading && !state.ended && (state.length < state.highWaterMark || state.flowing && state.length === 0)) {
        var len = state.length;
        debug("maybeReadMore read 0");
        stream.read(0);
        if (len === state.length)
          break;
      }
      state.readingMore = false;
    }
    Readable.prototype._read = function(n) {
      errorOrDestroy(this, new ERR_METHOD_NOT_IMPLEMENTED("_read()"));
    };
    Readable.prototype.pipe = function(dest, pipeOpts) {
      var src = this;
      var state = this._readableState;
      switch (state.pipesCount) {
        case 0:
          state.pipes = dest;
          break;
        case 1:
          state.pipes = [state.pipes, dest];
          break;
        default:
          state.pipes.push(dest);
          break;
      }
      state.pipesCount += 1;
      debug("pipe count=%d opts=%j", state.pipesCount, pipeOpts);
      var doEnd = (!pipeOpts || pipeOpts.end !== false) && dest !== process.stdout && dest !== process.stderr;
      var endFn = doEnd ? onend : unpipe;
      if (state.endEmitted) process.nextTick(endFn);
      else src.once("end", endFn);
      dest.on("unpipe", onunpipe);
      function onunpipe(readable, unpipeInfo) {
        debug("onunpipe");
        if (readable === src) {
          if (unpipeInfo && unpipeInfo.hasUnpiped === false) {
            unpipeInfo.hasUnpiped = true;
            cleanup();
          }
        }
      }
      function onend() {
        debug("onend");
        dest.end();
      }
      var ondrain = pipeOnDrain(src);
      dest.on("drain", ondrain);
      var cleanedUp = false;
      function cleanup() {
        debug("cleanup");
        dest.removeListener("close", onclose);
        dest.removeListener("finish", onfinish);
        dest.removeListener("drain", ondrain);
        dest.removeListener("error", onerror);
        dest.removeListener("unpipe", onunpipe);
        src.removeListener("end", onend);
        src.removeListener("end", unpipe);
        src.removeListener("data", ondata);
        cleanedUp = true;
        if (state.awaitDrain && (!dest._writableState || dest._writableState.needDrain)) ondrain();
      }
      src.on("data", ondata);
      function ondata(chunk) {
        debug("ondata");
        var ret = dest.write(chunk);
        debug("dest.write", ret);
        if (ret === false) {
          if ((state.pipesCount === 1 && state.pipes === dest || state.pipesCount > 1 && indexOf(state.pipes, dest) !== -1) && !cleanedUp) {
            debug("false write response, pause", state.awaitDrain);
            state.awaitDrain++;
          }
          src.pause();
        }
      }
      function onerror(er) {
        debug("onerror", er);
        unpipe();
        dest.removeListener("error", onerror);
        if (EElistenerCount(dest, "error") === 0) errorOrDestroy(dest, er);
      }
      prependListener(dest, "error", onerror);
      function onclose() {
        dest.removeListener("finish", onfinish);
        unpipe();
      }
      dest.once("close", onclose);
      function onfinish() {
        debug("onfinish");
        dest.removeListener("close", onclose);
        unpipe();
      }
      dest.once("finish", onfinish);
      function unpipe() {
        debug("unpipe");
        src.unpipe(dest);
      }
      dest.emit("pipe", src);
      if (!state.flowing) {
        debug("pipe resume");
        src.resume();
      }
      return dest;
    };
    function pipeOnDrain(src) {
      return function pipeOnDrainFunctionResult() {
        var state = src._readableState;
        debug("pipeOnDrain", state.awaitDrain);
        if (state.awaitDrain) state.awaitDrain--;
        if (state.awaitDrain === 0 && EElistenerCount(src, "data")) {
          state.flowing = true;
          flow(src);
        }
      };
    }
    Readable.prototype.unpipe = function(dest) {
      var state = this._readableState;
      var unpipeInfo = {
        hasUnpiped: false
      };
      if (state.pipesCount === 0) return this;
      if (state.pipesCount === 1) {
        if (dest && dest !== state.pipes) return this;
        if (!dest) dest = state.pipes;
        state.pipes = null;
        state.pipesCount = 0;
        state.flowing = false;
        if (dest) dest.emit("unpipe", this, unpipeInfo);
        return this;
      }
      if (!dest) {
        var dests = state.pipes;
        var len = state.pipesCount;
        state.pipes = null;
        state.pipesCount = 0;
        state.flowing = false;
        for (var i = 0; i < len; i++) dests[i].emit("unpipe", this, {
          hasUnpiped: false
        });
        return this;
      }
      var index = indexOf(state.pipes, dest);
      if (index === -1) return this;
      state.pipes.splice(index, 1);
      state.pipesCount -= 1;
      if (state.pipesCount === 1) state.pipes = state.pipes[0];
      dest.emit("unpipe", this, unpipeInfo);
      return this;
    };
    Readable.prototype.on = function(ev, fn) {
      var res = Stream.prototype.on.call(this, ev, fn);
      var state = this._readableState;
      if (ev === "data") {
        state.readableListening = this.listenerCount("readable") > 0;
        if (state.flowing !== false) this.resume();
      } else if (ev === "readable") {
        if (!state.endEmitted && !state.readableListening) {
          state.readableListening = state.needReadable = true;
          state.flowing = false;
          state.emittedReadable = false;
          debug("on readable", state.length, state.reading);
          if (state.length) {
            emitReadable(this);
          } else if (!state.reading) {
            process.nextTick(nReadingNextTick, this);
          }
        }
      }
      return res;
    };
    Readable.prototype.addListener = Readable.prototype.on;
    Readable.prototype.removeListener = function(ev, fn) {
      var res = Stream.prototype.removeListener.call(this, ev, fn);
      if (ev === "readable") {
        process.nextTick(updateReadableListening, this);
      }
      return res;
    };
    Readable.prototype.removeAllListeners = function(ev) {
      var res = Stream.prototype.removeAllListeners.apply(this, arguments);
      if (ev === "readable" || ev === void 0) {
        process.nextTick(updateReadableListening, this);
      }
      return res;
    };
    function updateReadableListening(self2) {
      var state = self2._readableState;
      state.readableListening = self2.listenerCount("readable") > 0;
      if (state.resumeScheduled && !state.paused) {
        state.flowing = true;
      } else if (self2.listenerCount("data") > 0) {
        self2.resume();
      }
    }
    function nReadingNextTick(self2) {
      debug("readable nexttick read 0");
      self2.read(0);
    }
    Readable.prototype.resume = function() {
      var state = this._readableState;
      if (!state.flowing) {
        debug("resume");
        state.flowing = !state.readableListening;
        resume(this, state);
      }
      state.paused = false;
      return this;
    };
    function resume(stream, state) {
      if (!state.resumeScheduled) {
        state.resumeScheduled = true;
        process.nextTick(resume_, stream, state);
      }
    }
    function resume_(stream, state) {
      debug("resume", state.reading);
      if (!state.reading) {
        stream.read(0);
      }
      state.resumeScheduled = false;
      stream.emit("resume");
      flow(stream);
      if (state.flowing && !state.reading) stream.read(0);
    }
    Readable.prototype.pause = function() {
      debug("call pause flowing=%j", this._readableState.flowing);
      if (this._readableState.flowing !== false) {
        debug("pause");
        this._readableState.flowing = false;
        this.emit("pause");
      }
      this._readableState.paused = true;
      return this;
    };
    function flow(stream) {
      var state = stream._readableState;
      debug("flow", state.flowing);
      while (state.flowing && stream.read() !== null) ;
    }
    Readable.prototype.wrap = function(stream) {
      var _this = this;
      var state = this._readableState;
      var paused = false;
      stream.on("end", function() {
        debug("wrapped end");
        if (state.decoder && !state.ended) {
          var chunk = state.decoder.end();
          if (chunk && chunk.length) _this.push(chunk);
        }
        _this.push(null);
      });
      stream.on("data", function(chunk) {
        debug("wrapped data");
        if (state.decoder) chunk = state.decoder.write(chunk);
        if (state.objectMode && (chunk === null || chunk === void 0)) return;
        else if (!state.objectMode && (!chunk || !chunk.length)) return;
        var ret = _this.push(chunk);
        if (!ret) {
          paused = true;
          stream.pause();
        }
      });
      for (var i in stream) {
        if (this[i] === void 0 && typeof stream[i] === "function") {
          this[i] = /* @__PURE__ */ (function methodWrap(method) {
            return function methodWrapReturnFunction() {
              return stream[method].apply(stream, arguments);
            };
          })(i);
        }
      }
      for (var n = 0; n < kProxyEvents.length; n++) {
        stream.on(kProxyEvents[n], this.emit.bind(this, kProxyEvents[n]));
      }
      this._read = function(n2) {
        debug("wrapped _read", n2);
        if (paused) {
          paused = false;
          stream.resume();
        }
      };
      return this;
    };
    if (typeof Symbol === "function") {
      Readable.prototype[Symbol.asyncIterator] = function() {
        if (createReadableStreamAsyncIterator === void 0) {
          createReadableStreamAsyncIterator = require_async_iterator();
        }
        return createReadableStreamAsyncIterator(this);
      };
    }
    Object.defineProperty(Readable.prototype, "readableHighWaterMark", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        return this._readableState.highWaterMark;
      }
    });
    Object.defineProperty(Readable.prototype, "readableBuffer", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        return this._readableState && this._readableState.buffer;
      }
    });
    Object.defineProperty(Readable.prototype, "readableFlowing", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        return this._readableState.flowing;
      },
      set: function set(state) {
        if (this._readableState) {
          this._readableState.flowing = state;
        }
      }
    });
    Readable._fromList = fromList;
    Object.defineProperty(Readable.prototype, "readableLength", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        return this._readableState.length;
      }
    });
    function fromList(n, state) {
      if (state.length === 0) return null;
      var ret;
      if (state.objectMode) ret = state.buffer.shift();
      else if (!n || n >= state.length) {
        if (state.decoder) ret = state.buffer.join("");
        else if (state.buffer.length === 1) ret = state.buffer.first();
        else ret = state.buffer.concat(state.length);
        state.buffer.clear();
      } else {
        ret = state.buffer.consume(n, state.decoder);
      }
      return ret;
    }
    function endReadable(stream) {
      var state = stream._readableState;
      debug("endReadable", state.endEmitted);
      if (!state.endEmitted) {
        state.ended = true;
        process.nextTick(endReadableNT, state, stream);
      }
    }
    function endReadableNT(state, stream) {
      debug("endReadableNT", state.endEmitted, state.length);
      if (!state.endEmitted && state.length === 0) {
        state.endEmitted = true;
        stream.readable = false;
        stream.emit("end");
        if (state.autoDestroy) {
          var wState = stream._writableState;
          if (!wState || wState.autoDestroy && wState.finished) {
            stream.destroy();
          }
        }
      }
    }
    if (typeof Symbol === "function") {
      Readable.from = function(iterable, opts) {
        if (from === void 0) {
          from = require_from();
        }
        return from(Readable, iterable, opts);
      };
    }
    function indexOf(xs, x) {
      for (var i = 0, l = xs.length; i < l; i++) {
        if (xs[i] === x) return i;
      }
      return -1;
    }
  }
});

// node_modules/readable-stream/lib/_stream_duplex.js
var require_stream_duplex = __commonJS({
  "node_modules/readable-stream/lib/_stream_duplex.js"(exports2, module2) {
    "use strict";
    var objectKeys = Object.keys || function(obj) {
      var keys2 = [];
      for (var key in obj) keys2.push(key);
      return keys2;
    };
    module2.exports = Duplex;
    var Readable = require_stream_readable();
    var Writable = require_stream_writable();
    require_inherits()(Duplex, Readable);
    {
      keys = objectKeys(Writable.prototype);
      for (v = 0; v < keys.length; v++) {
        method = keys[v];
        if (!Duplex.prototype[method]) Duplex.prototype[method] = Writable.prototype[method];
      }
    }
    var keys;
    var method;
    var v;
    function Duplex(options) {
      if (!(this instanceof Duplex)) return new Duplex(options);
      Readable.call(this, options);
      Writable.call(this, options);
      this.allowHalfOpen = true;
      if (options) {
        if (options.readable === false) this.readable = false;
        if (options.writable === false) this.writable = false;
        if (options.allowHalfOpen === false) {
          this.allowHalfOpen = false;
          this.once("end", onend);
        }
      }
    }
    Object.defineProperty(Duplex.prototype, "writableHighWaterMark", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        return this._writableState.highWaterMark;
      }
    });
    Object.defineProperty(Duplex.prototype, "writableBuffer", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        return this._writableState && this._writableState.getBuffer();
      }
    });
    Object.defineProperty(Duplex.prototype, "writableLength", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        return this._writableState.length;
      }
    });
    function onend() {
      if (this._writableState.ended) return;
      process.nextTick(onEndNT, this);
    }
    function onEndNT(self2) {
      self2.end();
    }
    Object.defineProperty(Duplex.prototype, "destroyed", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        if (this._readableState === void 0 || this._writableState === void 0) {
          return false;
        }
        return this._readableState.destroyed && this._writableState.destroyed;
      },
      set: function set(value) {
        if (this._readableState === void 0 || this._writableState === void 0) {
          return;
        }
        this._readableState.destroyed = value;
        this._writableState.destroyed = value;
      }
    });
  }
});

// node_modules/readable-stream/lib/_stream_writable.js
var require_stream_writable = __commonJS({
  "node_modules/readable-stream/lib/_stream_writable.js"(exports2, module2) {
    "use strict";
    module2.exports = Writable;
    function CorkedRequest(state) {
      var _this = this;
      this.next = null;
      this.entry = null;
      this.finish = function() {
        onCorkedFinish(_this, state);
      };
    }
    var Duplex;
    Writable.WritableState = WritableState;
    var internalUtil = {
      deprecate: require_node()
    };
    var Stream = require_stream();
    var Buffer2 = require("buffer").Buffer;
    var OurUint8Array = (typeof global !== "undefined" ? global : typeof window !== "undefined" ? window : typeof self !== "undefined" ? self : {}).Uint8Array || function() {
    };
    function _uint8ArrayToBuffer(chunk) {
      return Buffer2.from(chunk);
    }
    function _isUint8Array(obj) {
      return Buffer2.isBuffer(obj) || obj instanceof OurUint8Array;
    }
    var destroyImpl = require_destroy();
    var _require = require_state();
    var getHighWaterMark = _require.getHighWaterMark;
    var _require$codes = require_errors2().codes;
    var ERR_INVALID_ARG_TYPE = _require$codes.ERR_INVALID_ARG_TYPE;
    var ERR_METHOD_NOT_IMPLEMENTED = _require$codes.ERR_METHOD_NOT_IMPLEMENTED;
    var ERR_MULTIPLE_CALLBACK = _require$codes.ERR_MULTIPLE_CALLBACK;
    var ERR_STREAM_CANNOT_PIPE = _require$codes.ERR_STREAM_CANNOT_PIPE;
    var ERR_STREAM_DESTROYED = _require$codes.ERR_STREAM_DESTROYED;
    var ERR_STREAM_NULL_VALUES = _require$codes.ERR_STREAM_NULL_VALUES;
    var ERR_STREAM_WRITE_AFTER_END = _require$codes.ERR_STREAM_WRITE_AFTER_END;
    var ERR_UNKNOWN_ENCODING = _require$codes.ERR_UNKNOWN_ENCODING;
    var errorOrDestroy = destroyImpl.errorOrDestroy;
    require_inherits()(Writable, Stream);
    function nop() {
    }
    function WritableState(options, stream, isDuplex) {
      Duplex = Duplex || require_stream_duplex();
      options = options || {};
      if (typeof isDuplex !== "boolean") isDuplex = stream instanceof Duplex;
      this.objectMode = !!options.objectMode;
      if (isDuplex) this.objectMode = this.objectMode || !!options.writableObjectMode;
      this.highWaterMark = getHighWaterMark(this, options, "writableHighWaterMark", isDuplex);
      this.finalCalled = false;
      this.needDrain = false;
      this.ending = false;
      this.ended = false;
      this.finished = false;
      this.destroyed = false;
      var noDecode = options.decodeStrings === false;
      this.decodeStrings = !noDecode;
      this.defaultEncoding = options.defaultEncoding || "utf8";
      this.length = 0;
      this.writing = false;
      this.corked = 0;
      this.sync = true;
      this.bufferProcessing = false;
      this.onwrite = function(er) {
        onwrite(stream, er);
      };
      this.writecb = null;
      this.writelen = 0;
      this.bufferedRequest = null;
      this.lastBufferedRequest = null;
      this.pendingcb = 0;
      this.prefinished = false;
      this.errorEmitted = false;
      this.emitClose = options.emitClose !== false;
      this.autoDestroy = !!options.autoDestroy;
      this.bufferedRequestCount = 0;
      this.corkedRequestsFree = new CorkedRequest(this);
    }
    WritableState.prototype.getBuffer = function getBuffer() {
      var current = this.bufferedRequest;
      var out = [];
      while (current) {
        out.push(current);
        current = current.next;
      }
      return out;
    };
    (function() {
      try {
        Object.defineProperty(WritableState.prototype, "buffer", {
          get: internalUtil.deprecate(function writableStateBufferGetter() {
            return this.getBuffer();
          }, "_writableState.buffer is deprecated. Use _writableState.getBuffer instead.", "DEP0003")
        });
      } catch (_) {
      }
    })();
    var realHasInstance;
    if (typeof Symbol === "function" && Symbol.hasInstance && typeof Function.prototype[Symbol.hasInstance] === "function") {
      realHasInstance = Function.prototype[Symbol.hasInstance];
      Object.defineProperty(Writable, Symbol.hasInstance, {
        value: function value(object) {
          if (realHasInstance.call(this, object)) return true;
          if (this !== Writable) return false;
          return object && object._writableState instanceof WritableState;
        }
      });
    } else {
      realHasInstance = function realHasInstance2(object) {
        return object instanceof this;
      };
    }
    function Writable(options) {
      Duplex = Duplex || require_stream_duplex();
      var isDuplex = this instanceof Duplex;
      if (!isDuplex && !realHasInstance.call(Writable, this)) return new Writable(options);
      this._writableState = new WritableState(options, this, isDuplex);
      this.writable = true;
      if (options) {
        if (typeof options.write === "function") this._write = options.write;
        if (typeof options.writev === "function") this._writev = options.writev;
        if (typeof options.destroy === "function") this._destroy = options.destroy;
        if (typeof options.final === "function") this._final = options.final;
      }
      Stream.call(this);
    }
    Writable.prototype.pipe = function() {
      errorOrDestroy(this, new ERR_STREAM_CANNOT_PIPE());
    };
    function writeAfterEnd(stream, cb) {
      var er = new ERR_STREAM_WRITE_AFTER_END();
      errorOrDestroy(stream, er);
      process.nextTick(cb, er);
    }
    function validChunk(stream, state, chunk, cb) {
      var er;
      if (chunk === null) {
        er = new ERR_STREAM_NULL_VALUES();
      } else if (typeof chunk !== "string" && !state.objectMode) {
        er = new ERR_INVALID_ARG_TYPE("chunk", ["string", "Buffer"], chunk);
      }
      if (er) {
        errorOrDestroy(stream, er);
        process.nextTick(cb, er);
        return false;
      }
      return true;
    }
    Writable.prototype.write = function(chunk, encoding, cb) {
      var state = this._writableState;
      var ret = false;
      var isBuf = !state.objectMode && _isUint8Array(chunk);
      if (isBuf && !Buffer2.isBuffer(chunk)) {
        chunk = _uint8ArrayToBuffer(chunk);
      }
      if (typeof encoding === "function") {
        cb = encoding;
        encoding = null;
      }
      if (isBuf) encoding = "buffer";
      else if (!encoding) encoding = state.defaultEncoding;
      if (typeof cb !== "function") cb = nop;
      if (state.ending) writeAfterEnd(this, cb);
      else if (isBuf || validChunk(this, state, chunk, cb)) {
        state.pendingcb++;
        ret = writeOrBuffer(this, state, isBuf, chunk, encoding, cb);
      }
      return ret;
    };
    Writable.prototype.cork = function() {
      this._writableState.corked++;
    };
    Writable.prototype.uncork = function() {
      var state = this._writableState;
      if (state.corked) {
        state.corked--;
        if (!state.writing && !state.corked && !state.bufferProcessing && state.bufferedRequest) clearBuffer(this, state);
      }
    };
    Writable.prototype.setDefaultEncoding = function setDefaultEncoding(encoding) {
      if (typeof encoding === "string") encoding = encoding.toLowerCase();
      if (!(["hex", "utf8", "utf-8", "ascii", "binary", "base64", "ucs2", "ucs-2", "utf16le", "utf-16le", "raw"].indexOf((encoding + "").toLowerCase()) > -1)) throw new ERR_UNKNOWN_ENCODING(encoding);
      this._writableState.defaultEncoding = encoding;
      return this;
    };
    Object.defineProperty(Writable.prototype, "writableBuffer", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        return this._writableState && this._writableState.getBuffer();
      }
    });
    function decodeChunk(state, chunk, encoding) {
      if (!state.objectMode && state.decodeStrings !== false && typeof chunk === "string") {
        chunk = Buffer2.from(chunk, encoding);
      }
      return chunk;
    }
    Object.defineProperty(Writable.prototype, "writableHighWaterMark", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        return this._writableState.highWaterMark;
      }
    });
    function writeOrBuffer(stream, state, isBuf, chunk, encoding, cb) {
      if (!isBuf) {
        var newChunk = decodeChunk(state, chunk, encoding);
        if (chunk !== newChunk) {
          isBuf = true;
          encoding = "buffer";
          chunk = newChunk;
        }
      }
      var len = state.objectMode ? 1 : chunk.length;
      state.length += len;
      var ret = state.length < state.highWaterMark;
      if (!ret) state.needDrain = true;
      if (state.writing || state.corked) {
        var last = state.lastBufferedRequest;
        state.lastBufferedRequest = {
          chunk,
          encoding,
          isBuf,
          callback: cb,
          next: null
        };
        if (last) {
          last.next = state.lastBufferedRequest;
        } else {
          state.bufferedRequest = state.lastBufferedRequest;
        }
        state.bufferedRequestCount += 1;
      } else {
        doWrite(stream, state, false, len, chunk, encoding, cb);
      }
      return ret;
    }
    function doWrite(stream, state, writev, len, chunk, encoding, cb) {
      state.writelen = len;
      state.writecb = cb;
      state.writing = true;
      state.sync = true;
      if (state.destroyed) state.onwrite(new ERR_STREAM_DESTROYED("write"));
      else if (writev) stream._writev(chunk, state.onwrite);
      else stream._write(chunk, encoding, state.onwrite);
      state.sync = false;
    }
    function onwriteError(stream, state, sync, er, cb) {
      --state.pendingcb;
      if (sync) {
        process.nextTick(cb, er);
        process.nextTick(finishMaybe, stream, state);
        stream._writableState.errorEmitted = true;
        errorOrDestroy(stream, er);
      } else {
        cb(er);
        stream._writableState.errorEmitted = true;
        errorOrDestroy(stream, er);
        finishMaybe(stream, state);
      }
    }
    function onwriteStateUpdate(state) {
      state.writing = false;
      state.writecb = null;
      state.length -= state.writelen;
      state.writelen = 0;
    }
    function onwrite(stream, er) {
      var state = stream._writableState;
      var sync = state.sync;
      var cb = state.writecb;
      if (typeof cb !== "function") throw new ERR_MULTIPLE_CALLBACK();
      onwriteStateUpdate(state);
      if (er) onwriteError(stream, state, sync, er, cb);
      else {
        var finished = needFinish(state) || stream.destroyed;
        if (!finished && !state.corked && !state.bufferProcessing && state.bufferedRequest) {
          clearBuffer(stream, state);
        }
        if (sync) {
          process.nextTick(afterWrite, stream, state, finished, cb);
        } else {
          afterWrite(stream, state, finished, cb);
        }
      }
    }
    function afterWrite(stream, state, finished, cb) {
      if (!finished) onwriteDrain(stream, state);
      state.pendingcb--;
      cb();
      finishMaybe(stream, state);
    }
    function onwriteDrain(stream, state) {
      if (state.length === 0 && state.needDrain) {
        state.needDrain = false;
        stream.emit("drain");
      }
    }
    function clearBuffer(stream, state) {
      state.bufferProcessing = true;
      var entry = state.bufferedRequest;
      if (stream._writev && entry && entry.next) {
        var l = state.bufferedRequestCount;
        var buffer = new Array(l);
        var holder = state.corkedRequestsFree;
        holder.entry = entry;
        var count = 0;
        var allBuffers = true;
        while (entry) {
          buffer[count] = entry;
          if (!entry.isBuf) allBuffers = false;
          entry = entry.next;
          count += 1;
        }
        buffer.allBuffers = allBuffers;
        doWrite(stream, state, true, state.length, buffer, "", holder.finish);
        state.pendingcb++;
        state.lastBufferedRequest = null;
        if (holder.next) {
          state.corkedRequestsFree = holder.next;
          holder.next = null;
        } else {
          state.corkedRequestsFree = new CorkedRequest(state);
        }
        state.bufferedRequestCount = 0;
      } else {
        while (entry) {
          var chunk = entry.chunk;
          var encoding = entry.encoding;
          var cb = entry.callback;
          var len = state.objectMode ? 1 : chunk.length;
          doWrite(stream, state, false, len, chunk, encoding, cb);
          entry = entry.next;
          state.bufferedRequestCount--;
          if (state.writing) {
            break;
          }
        }
        if (entry === null) state.lastBufferedRequest = null;
      }
      state.bufferedRequest = entry;
      state.bufferProcessing = false;
    }
    Writable.prototype._write = function(chunk, encoding, cb) {
      cb(new ERR_METHOD_NOT_IMPLEMENTED("_write()"));
    };
    Writable.prototype._writev = null;
    Writable.prototype.end = function(chunk, encoding, cb) {
      var state = this._writableState;
      if (typeof chunk === "function") {
        cb = chunk;
        chunk = null;
        encoding = null;
      } else if (typeof encoding === "function") {
        cb = encoding;
        encoding = null;
      }
      if (chunk !== null && chunk !== void 0) this.write(chunk, encoding);
      if (state.corked) {
        state.corked = 1;
        this.uncork();
      }
      if (!state.ending) endWritable(this, state, cb);
      return this;
    };
    Object.defineProperty(Writable.prototype, "writableLength", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        return this._writableState.length;
      }
    });
    function needFinish(state) {
      return state.ending && state.length === 0 && state.bufferedRequest === null && !state.finished && !state.writing;
    }
    function callFinal(stream, state) {
      stream._final(function(err) {
        state.pendingcb--;
        if (err) {
          errorOrDestroy(stream, err);
        }
        state.prefinished = true;
        stream.emit("prefinish");
        finishMaybe(stream, state);
      });
    }
    function prefinish(stream, state) {
      if (!state.prefinished && !state.finalCalled) {
        if (typeof stream._final === "function" && !state.destroyed) {
          state.pendingcb++;
          state.finalCalled = true;
          process.nextTick(callFinal, stream, state);
        } else {
          state.prefinished = true;
          stream.emit("prefinish");
        }
      }
    }
    function finishMaybe(stream, state) {
      var need = needFinish(state);
      if (need) {
        prefinish(stream, state);
        if (state.pendingcb === 0) {
          state.finished = true;
          stream.emit("finish");
          if (state.autoDestroy) {
            var rState = stream._readableState;
            if (!rState || rState.autoDestroy && rState.endEmitted) {
              stream.destroy();
            }
          }
        }
      }
      return need;
    }
    function endWritable(stream, state, cb) {
      state.ending = true;
      finishMaybe(stream, state);
      if (cb) {
        if (state.finished) process.nextTick(cb);
        else stream.once("finish", cb);
      }
      state.ended = true;
      stream.writable = false;
    }
    function onCorkedFinish(corkReq, state, err) {
      var entry = corkReq.entry;
      corkReq.entry = null;
      while (entry) {
        var cb = entry.callback;
        state.pendingcb--;
        cb(err);
        entry = entry.next;
      }
      state.corkedRequestsFree.next = corkReq;
    }
    Object.defineProperty(Writable.prototype, "destroyed", {
      // making it explicit this property is not enumerable
      // because otherwise some prototype manipulation in
      // userland will fail
      enumerable: false,
      get: function get() {
        if (this._writableState === void 0) {
          return false;
        }
        return this._writableState.destroyed;
      },
      set: function set(value) {
        if (!this._writableState) {
          return;
        }
        this._writableState.destroyed = value;
      }
    });
    Writable.prototype.destroy = destroyImpl.destroy;
    Writable.prototype._undestroy = destroyImpl.undestroy;
    Writable.prototype._destroy = function(err, cb) {
      cb(err);
    };
  }
});

// node_modules/winston-transport/modern.js
var require_modern = __commonJS({
  "node_modules/winston-transport/modern.js"(exports2, module2) {
    "use strict";
    var util = require("util");
    var Writable = require_stream_writable();
    var { LEVEL } = require_triple_beam();
    var TransportStream = module2.exports = function TransportStream2(options = {}) {
      Writable.call(this, { objectMode: true, highWaterMark: options.highWaterMark });
      this.format = options.format;
      this.level = options.level;
      this.handleExceptions = options.handleExceptions;
      this.handleRejections = options.handleRejections;
      this.silent = options.silent;
      if (options.log) this.log = options.log;
      if (options.logv) this.logv = options.logv;
      if (options.close) this.close = options.close;
      this.once("pipe", (logger3) => {
        this.levels = logger3.levels;
        this.parent = logger3;
      });
      this.once("unpipe", (src) => {
        if (src === this.parent) {
          this.parent = null;
          if (this.close) {
            this.close();
          }
        }
      });
    };
    util.inherits(TransportStream, Writable);
    TransportStream.prototype._write = function _write(info, enc, callback) {
      if (this.silent || info.exception === true && !this.handleExceptions) {
        return callback(null);
      }
      const level = this.level || this.parent && this.parent.level;
      if (!level || this.levels[level] >= this.levels[info[LEVEL]]) {
        if (info && !this.format) {
          return this.log(info, callback);
        }
        let errState;
        let transformed;
        try {
          transformed = this.format.transform(Object.assign({}, info), this.format.options);
        } catch (err) {
          errState = err;
        }
        if (errState || !transformed) {
          callback();
          if (errState) throw errState;
          return;
        }
        return this.log(transformed, callback);
      }
      this._writableState.sync = false;
      return callback(null);
    };
    TransportStream.prototype._writev = function _writev(chunks, callback) {
      if (this.logv) {
        const infos = chunks.filter(this._accept, this);
        if (!infos.length) {
          return callback(null);
        }
        return this.logv(infos, callback);
      }
      for (let i = 0; i < chunks.length; i++) {
        if (!this._accept(chunks[i])) continue;
        if (chunks[i].chunk && !this.format) {
          this.log(chunks[i].chunk, chunks[i].callback);
          continue;
        }
        let errState;
        let transformed;
        try {
          transformed = this.format.transform(
            Object.assign({}, chunks[i].chunk),
            this.format.options
          );
        } catch (err) {
          errState = err;
        }
        if (errState || !transformed) {
          chunks[i].callback();
          if (errState) {
            callback(null);
            throw errState;
          }
        } else {
          this.log(transformed, chunks[i].callback);
        }
      }
      return callback(null);
    };
    TransportStream.prototype._accept = function _accept(write) {
      const info = write.chunk;
      if (this.silent) {
        return false;
      }
      const level = this.level || this.parent && this.parent.level;
      if (info.exception === true || !level || this.levels[level] >= this.levels[info[LEVEL]]) {
        if (this.handleExceptions || info.exception !== true) {
          return true;
        }
      }
      return false;
    };
    TransportStream.prototype._nop = function _nop() {
      return void 0;
    };
  }
});

// node_modules/winston-transport/legacy.js
var require_legacy = __commonJS({
  "node_modules/winston-transport/legacy.js"(exports2, module2) {
    "use strict";
    var util = require("util");
    var { LEVEL } = require_triple_beam();
    var TransportStream = require_modern();
    var LegacyTransportStream = module2.exports = function LegacyTransportStream2(options = {}) {
      TransportStream.call(this, options);
      if (!options.transport || typeof options.transport.log !== "function") {
        throw new Error("Invalid transport, must be an object with a log method.");
      }
      this.transport = options.transport;
      this.level = this.level || options.transport.level;
      this.handleExceptions = this.handleExceptions || options.transport.handleExceptions;
      this._deprecated();
      function transportError(err) {
        this.emit("error", err, this.transport);
      }
      if (!this.transport.__winstonError) {
        this.transport.__winstonError = transportError.bind(this);
        this.transport.on("error", this.transport.__winstonError);
      }
    };
    util.inherits(LegacyTransportStream, TransportStream);
    LegacyTransportStream.prototype._write = function _write(info, enc, callback) {
      if (this.silent || info.exception === true && !this.handleExceptions) {
        return callback(null);
      }
      if (!this.level || this.levels[this.level] >= this.levels[info[LEVEL]]) {
        this.transport.log(info[LEVEL], info.message, info, this._nop);
      }
      callback(null);
    };
    LegacyTransportStream.prototype._writev = function _writev(chunks, callback) {
      for (let i = 0; i < chunks.length; i++) {
        if (this._accept(chunks[i])) {
          this.transport.log(
            chunks[i].chunk[LEVEL],
            chunks[i].chunk.message,
            chunks[i].chunk,
            this._nop
          );
          chunks[i].callback();
        }
      }
      return callback(null);
    };
    LegacyTransportStream.prototype._deprecated = function _deprecated() {
      console.error([
        `${this.transport.name} is a legacy winston transport. Consider upgrading: `,
        "- Upgrade docs: https://github.com/winstonjs/winston/blob/master/UPGRADE-3.0.md"
      ].join("\n"));
    };
    LegacyTransportStream.prototype.close = function close() {
      if (this.transport.close) {
        this.transport.close();
      }
      if (this.transport.__winstonError) {
        this.transport.removeListener("error", this.transport.__winstonError);
        this.transport.__winstonError = null;
      }
    };
  }
});

// node_modules/winston-transport/index.js
var require_winston_transport = __commonJS({
  "node_modules/winston-transport/index.js"(exports2, module2) {
    "use strict";
    module2.exports = require_modern();
    module2.exports.LegacyTransportStream = require_legacy();
  }
});

// node_modules/winston/lib/winston/transports/console.js
var require_console = __commonJS({
  "node_modules/winston/lib/winston/transports/console.js"(exports2, module2) {
    "use strict";
    var os2 = require("os");
    var { LEVEL, MESSAGE } = require_triple_beam();
    var TransportStream = require_winston_transport();
    module2.exports = class Console extends TransportStream {
      /**
       * Constructor function for the Console transport object responsible for
       * persisting log messages and metadata to a terminal or TTY.
       * @param {!Object} [options={}] - Options for this instance.
       */
      constructor(options = {}) {
        super(options);
        this.name = options.name || "console";
        this.stderrLevels = this._stringArrayToSet(options.stderrLevels);
        this.consoleWarnLevels = this._stringArrayToSet(options.consoleWarnLevels);
        this.eol = typeof options.eol === "string" ? options.eol : os2.EOL;
        this.forceConsole = options.forceConsole || false;
        this._consoleLog = console.log.bind(console);
        this._consoleWarn = console.warn.bind(console);
        this._consoleError = console.error.bind(console);
        this.setMaxListeners(30);
      }
      /**
       * Core logging method exposed to Winston.
       * @param {Object} info - TODO: add param description.
       * @param {Function} callback - TODO: add param description.
       * @returns {undefined}
       */
      log(info, callback) {
        setImmediate(() => this.emit("logged", info));
        if (this.stderrLevels[info[LEVEL]]) {
          if (console._stderr && !this.forceConsole) {
            console._stderr.write(`${info[MESSAGE]}${this.eol}`);
          } else {
            this._consoleError(info[MESSAGE]);
          }
          if (callback) {
            callback();
          }
          return;
        } else if (this.consoleWarnLevels[info[LEVEL]]) {
          if (console._stderr && !this.forceConsole) {
            console._stderr.write(`${info[MESSAGE]}${this.eol}`);
          } else {
            this._consoleWarn(info[MESSAGE]);
          }
          if (callback) {
            callback();
          }
          return;
        }
        if (console._stdout && !this.forceConsole) {
          console._stdout.write(`${info[MESSAGE]}${this.eol}`);
        } else {
          this._consoleLog(info[MESSAGE]);
        }
        if (callback) {
          callback();
        }
      }
      /**
       * Returns a Set-like object with strArray's elements as keys (each with the
       * value true).
       * @param {Array} strArray - Array of Set-elements as strings.
       * @param {?string} [errMsg] - Custom error message thrown on invalid input.
       * @returns {Object} - TODO: add return description.
       * @private
       */
      _stringArrayToSet(strArray, errMsg) {
        if (!strArray) return {};
        errMsg = errMsg || "Cannot make set from type other than Array of string elements";
        if (!Array.isArray(strArray)) {
          throw new Error(errMsg);
        }
        return strArray.reduce((set, el) => {
          if (typeof el !== "string") {
            throw new Error(errMsg);
          }
          set[el] = true;
          return set;
        }, {});
      }
    };
  }
});

// node_modules/async/internal/isArrayLike.js
var require_isArrayLike = __commonJS({
  "node_modules/async/internal/isArrayLike.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = isArrayLike;
    function isArrayLike(value) {
      return value && typeof value.length === "number" && value.length >= 0 && value.length % 1 === 0;
    }
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/initialParams.js
var require_initialParams = __commonJS({
  "node_modules/async/internal/initialParams.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = function(fn) {
      return function(...args) {
        var callback = args.pop();
        return fn.call(this, args, callback);
      };
    };
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/setImmediate.js
var require_setImmediate = __commonJS({
  "node_modules/async/internal/setImmediate.js"(exports2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.fallback = fallback;
    exports2.wrap = wrap;
    var hasQueueMicrotask = exports2.hasQueueMicrotask = typeof queueMicrotask === "function" && queueMicrotask;
    var hasSetImmediate = exports2.hasSetImmediate = typeof setImmediate === "function" && setImmediate;
    var hasNextTick = exports2.hasNextTick = typeof process === "object" && typeof process.nextTick === "function";
    function fallback(fn) {
      setTimeout(fn, 0);
    }
    function wrap(defer) {
      return (fn, ...args) => defer(() => fn(...args));
    }
    var _defer;
    if (hasQueueMicrotask) {
      _defer = queueMicrotask;
    } else if (hasSetImmediate) {
      _defer = setImmediate;
    } else if (hasNextTick) {
      _defer = process.nextTick;
    } else {
      _defer = fallback;
    }
    exports2.default = wrap(_defer);
  }
});

// node_modules/async/asyncify.js
var require_asyncify = __commonJS({
  "node_modules/async/asyncify.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = asyncify;
    var _initialParams = require_initialParams();
    var _initialParams2 = _interopRequireDefault(_initialParams);
    var _setImmediate = require_setImmediate();
    var _setImmediate2 = _interopRequireDefault(_setImmediate);
    var _wrapAsync = require_wrapAsync();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    function asyncify(func) {
      if ((0, _wrapAsync.isAsync)(func)) {
        return function(...args) {
          const callback = args.pop();
          const promise = func.apply(this, args);
          return handlePromise(promise, callback);
        };
      }
      return (0, _initialParams2.default)(function(args, callback) {
        var result;
        try {
          result = func.apply(this, args);
        } catch (e) {
          return callback(e);
        }
        if (result && typeof result.then === "function") {
          return handlePromise(result, callback);
        } else {
          callback(null, result);
        }
      });
    }
    function handlePromise(promise, callback) {
      return promise.then((value) => {
        invokeCallback(callback, null, value);
      }, (err) => {
        invokeCallback(callback, err && (err instanceof Error || err.message) ? err : new Error(err));
      });
    }
    function invokeCallback(callback, error, value) {
      try {
        callback(error, value);
      } catch (err) {
        (0, _setImmediate2.default)((e) => {
          throw e;
        }, err);
      }
    }
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/wrapAsync.js
var require_wrapAsync = __commonJS({
  "node_modules/async/internal/wrapAsync.js"(exports2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.isAsyncIterable = exports2.isAsyncGenerator = exports2.isAsync = void 0;
    var _asyncify = require_asyncify();
    var _asyncify2 = _interopRequireDefault(_asyncify);
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    function isAsync(fn) {
      return fn[Symbol.toStringTag] === "AsyncFunction";
    }
    function isAsyncGenerator(fn) {
      return fn[Symbol.toStringTag] === "AsyncGenerator";
    }
    function isAsyncIterable(obj) {
      return typeof obj[Symbol.asyncIterator] === "function";
    }
    function wrapAsync(asyncFn) {
      if (typeof asyncFn !== "function") throw new Error("expected a function");
      return isAsync(asyncFn) ? (0, _asyncify2.default)(asyncFn) : asyncFn;
    }
    exports2.default = wrapAsync;
    exports2.isAsync = isAsync;
    exports2.isAsyncGenerator = isAsyncGenerator;
    exports2.isAsyncIterable = isAsyncIterable;
  }
});

// node_modules/async/internal/awaitify.js
var require_awaitify = __commonJS({
  "node_modules/async/internal/awaitify.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = awaitify;
    function awaitify(asyncFn, arity) {
      if (!arity) arity = asyncFn.length;
      if (!arity) throw new Error("arity is undefined");
      function awaitable(...args) {
        if (typeof args[arity - 1] === "function") {
          return asyncFn.apply(this, args);
        }
        return new Promise((resolve, reject) => {
          args[arity - 1] = (err, ...cbArgs) => {
            if (err) return reject(err);
            resolve(cbArgs.length > 1 ? cbArgs : cbArgs[0]);
          };
          asyncFn.apply(this, args);
        });
      }
      return awaitable;
    }
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/parallel.js
var require_parallel = __commonJS({
  "node_modules/async/internal/parallel.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    var _isArrayLike = require_isArrayLike();
    var _isArrayLike2 = _interopRequireDefault(_isArrayLike);
    var _wrapAsync = require_wrapAsync();
    var _wrapAsync2 = _interopRequireDefault(_wrapAsync);
    var _awaitify = require_awaitify();
    var _awaitify2 = _interopRequireDefault(_awaitify);
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    exports2.default = (0, _awaitify2.default)((eachfn, tasks, callback) => {
      var results = (0, _isArrayLike2.default)(tasks) ? [] : {};
      eachfn(tasks, (task, key, taskCb) => {
        (0, _wrapAsync2.default)(task)((err, ...result) => {
          if (result.length < 2) {
            [result] = result;
          }
          results[key] = result;
          taskCb(err);
        });
      }, (err) => callback(err, results));
    }, 3);
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/once.js
var require_once = __commonJS({
  "node_modules/async/internal/once.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = once;
    function once(fn) {
      function wrapper(...args) {
        if (fn === null) return;
        var callFn = fn;
        fn = null;
        callFn.apply(this, args);
      }
      Object.assign(wrapper, fn);
      return wrapper;
    }
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/getIterator.js
var require_getIterator = __commonJS({
  "node_modules/async/internal/getIterator.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = function(coll) {
      return coll[Symbol.iterator] && coll[Symbol.iterator]();
    };
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/iterator.js
var require_iterator = __commonJS({
  "node_modules/async/internal/iterator.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = createIterator;
    var _isArrayLike = require_isArrayLike();
    var _isArrayLike2 = _interopRequireDefault(_isArrayLike);
    var _getIterator = require_getIterator();
    var _getIterator2 = _interopRequireDefault(_getIterator);
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    function createArrayIterator(coll) {
      var i = -1;
      var len = coll.length;
      return function next() {
        return ++i < len ? { value: coll[i], key: i } : null;
      };
    }
    function createES2015Iterator(iterator) {
      var i = -1;
      return function next() {
        var item = iterator.next();
        if (item.done) return null;
        i++;
        return { value: item.value, key: i };
      };
    }
    function createObjectIterator(obj) {
      var okeys = obj ? Object.keys(obj) : [];
      var i = -1;
      var len = okeys.length;
      return function next() {
        var key = okeys[++i];
        if (key === "__proto__") {
          return next();
        }
        return i < len ? { value: obj[key], key } : null;
      };
    }
    function createIterator(coll) {
      if ((0, _isArrayLike2.default)(coll)) {
        return createArrayIterator(coll);
      }
      var iterator = (0, _getIterator2.default)(coll);
      return iterator ? createES2015Iterator(iterator) : createObjectIterator(coll);
    }
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/onlyOnce.js
var require_onlyOnce = __commonJS({
  "node_modules/async/internal/onlyOnce.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = onlyOnce;
    function onlyOnce(fn) {
      return function(...args) {
        if (fn === null) throw new Error("Callback was already called.");
        var callFn = fn;
        fn = null;
        callFn.apply(this, args);
      };
    }
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/breakLoop.js
var require_breakLoop = __commonJS({
  "node_modules/async/internal/breakLoop.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    var breakLoop = {};
    exports2.default = breakLoop;
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/asyncEachOfLimit.js
var require_asyncEachOfLimit = __commonJS({
  "node_modules/async/internal/asyncEachOfLimit.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = asyncEachOfLimit;
    var _breakLoop = require_breakLoop();
    var _breakLoop2 = _interopRequireDefault(_breakLoop);
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    function asyncEachOfLimit(generator, limit, iteratee, callback) {
      let done = false;
      let canceled = false;
      let awaiting = false;
      let running = 0;
      let idx = 0;
      function replenish() {
        if (running >= limit || awaiting || done) return;
        awaiting = true;
        generator.next().then(({ value, done: iterDone }) => {
          if (canceled || done) return;
          awaiting = false;
          if (iterDone) {
            done = true;
            if (running <= 0) {
              callback(null);
            }
            return;
          }
          running++;
          iteratee(value, idx, iterateeCallback);
          idx++;
          replenish();
        }).catch(handleError);
      }
      function iterateeCallback(err, result) {
        running -= 1;
        if (canceled) return;
        if (err) return handleError(err);
        if (err === false) {
          done = true;
          canceled = true;
          return;
        }
        if (result === _breakLoop2.default || done && running <= 0) {
          done = true;
          return callback(null);
        }
        replenish();
      }
      function handleError(err) {
        if (canceled) return;
        awaiting = false;
        done = true;
        callback(err);
      }
      replenish();
    }
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/eachOfLimit.js
var require_eachOfLimit = __commonJS({
  "node_modules/async/internal/eachOfLimit.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    var _once = require_once();
    var _once2 = _interopRequireDefault(_once);
    var _iterator = require_iterator();
    var _iterator2 = _interopRequireDefault(_iterator);
    var _onlyOnce = require_onlyOnce();
    var _onlyOnce2 = _interopRequireDefault(_onlyOnce);
    var _wrapAsync = require_wrapAsync();
    var _asyncEachOfLimit = require_asyncEachOfLimit();
    var _asyncEachOfLimit2 = _interopRequireDefault(_asyncEachOfLimit);
    var _breakLoop = require_breakLoop();
    var _breakLoop2 = _interopRequireDefault(_breakLoop);
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    exports2.default = (limit) => {
      return (obj, iteratee, callback) => {
        callback = (0, _once2.default)(callback);
        if (limit <= 0) {
          throw new RangeError("concurrency limit cannot be less than 1");
        }
        if (!obj) {
          return callback(null);
        }
        if ((0, _wrapAsync.isAsyncGenerator)(obj)) {
          return (0, _asyncEachOfLimit2.default)(obj, limit, iteratee, callback);
        }
        if ((0, _wrapAsync.isAsyncIterable)(obj)) {
          return (0, _asyncEachOfLimit2.default)(obj[Symbol.asyncIterator](), limit, iteratee, callback);
        }
        var nextElem = (0, _iterator2.default)(obj);
        var done = false;
        var canceled = false;
        var running = 0;
        var looping = false;
        function iterateeCallback(err, value) {
          if (canceled) return;
          running -= 1;
          if (err) {
            done = true;
            callback(err);
          } else if (err === false) {
            done = true;
            canceled = true;
          } else if (value === _breakLoop2.default || done && running <= 0) {
            done = true;
            return callback(null);
          } else if (!looping) {
            replenish();
          }
        }
        function replenish() {
          looping = true;
          while (running < limit && !done) {
            var elem = nextElem();
            if (elem === null) {
              done = true;
              if (running <= 0) {
                callback(null);
              }
              return;
            }
            running += 1;
            iteratee(elem.value, elem.key, (0, _onlyOnce2.default)(iterateeCallback));
          }
          looping = false;
        }
        replenish();
      };
    };
    module2.exports = exports2.default;
  }
});

// node_modules/async/eachOfLimit.js
var require_eachOfLimit2 = __commonJS({
  "node_modules/async/eachOfLimit.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    var _eachOfLimit2 = require_eachOfLimit();
    var _eachOfLimit3 = _interopRequireDefault(_eachOfLimit2);
    var _wrapAsync = require_wrapAsync();
    var _wrapAsync2 = _interopRequireDefault(_wrapAsync);
    var _awaitify = require_awaitify();
    var _awaitify2 = _interopRequireDefault(_awaitify);
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    function eachOfLimit(coll, limit, iteratee, callback) {
      return (0, _eachOfLimit3.default)(limit)(coll, (0, _wrapAsync2.default)(iteratee), callback);
    }
    exports2.default = (0, _awaitify2.default)(eachOfLimit, 4);
    module2.exports = exports2.default;
  }
});

// node_modules/async/eachOfSeries.js
var require_eachOfSeries = __commonJS({
  "node_modules/async/eachOfSeries.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    var _eachOfLimit = require_eachOfLimit2();
    var _eachOfLimit2 = _interopRequireDefault(_eachOfLimit);
    var _awaitify = require_awaitify();
    var _awaitify2 = _interopRequireDefault(_awaitify);
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    function eachOfSeries(coll, iteratee, callback) {
      return (0, _eachOfLimit2.default)(coll, 1, iteratee, callback);
    }
    exports2.default = (0, _awaitify2.default)(eachOfSeries, 3);
    module2.exports = exports2.default;
  }
});

// node_modules/async/series.js
var require_series = __commonJS({
  "node_modules/async/series.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = series;
    var _parallel2 = require_parallel();
    var _parallel3 = _interopRequireDefault(_parallel2);
    var _eachOfSeries = require_eachOfSeries();
    var _eachOfSeries2 = _interopRequireDefault(_eachOfSeries);
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    function series(tasks, callback) {
      return (0, _parallel3.default)(_eachOfSeries2.default, tasks, callback);
    }
    module2.exports = exports2.default;
  }
});

// node_modules/readable-stream/lib/_stream_transform.js
var require_stream_transform = __commonJS({
  "node_modules/readable-stream/lib/_stream_transform.js"(exports2, module2) {
    "use strict";
    module2.exports = Transform;
    var _require$codes = require_errors2().codes;
    var ERR_METHOD_NOT_IMPLEMENTED = _require$codes.ERR_METHOD_NOT_IMPLEMENTED;
    var ERR_MULTIPLE_CALLBACK = _require$codes.ERR_MULTIPLE_CALLBACK;
    var ERR_TRANSFORM_ALREADY_TRANSFORMING = _require$codes.ERR_TRANSFORM_ALREADY_TRANSFORMING;
    var ERR_TRANSFORM_WITH_LENGTH_0 = _require$codes.ERR_TRANSFORM_WITH_LENGTH_0;
    var Duplex = require_stream_duplex();
    require_inherits()(Transform, Duplex);
    function afterTransform(er, data) {
      var ts = this._transformState;
      ts.transforming = false;
      var cb = ts.writecb;
      if (cb === null) {
        return this.emit("error", new ERR_MULTIPLE_CALLBACK());
      }
      ts.writechunk = null;
      ts.writecb = null;
      if (data != null)
        this.push(data);
      cb(er);
      var rs = this._readableState;
      rs.reading = false;
      if (rs.needReadable || rs.length < rs.highWaterMark) {
        this._read(rs.highWaterMark);
      }
    }
    function Transform(options) {
      if (!(this instanceof Transform)) return new Transform(options);
      Duplex.call(this, options);
      this._transformState = {
        afterTransform: afterTransform.bind(this),
        needTransform: false,
        transforming: false,
        writecb: null,
        writechunk: null,
        writeencoding: null
      };
      this._readableState.needReadable = true;
      this._readableState.sync = false;
      if (options) {
        if (typeof options.transform === "function") this._transform = options.transform;
        if (typeof options.flush === "function") this._flush = options.flush;
      }
      this.on("prefinish", prefinish);
    }
    function prefinish() {
      var _this = this;
      if (typeof this._flush === "function" && !this._readableState.destroyed) {
        this._flush(function(er, data) {
          done(_this, er, data);
        });
      } else {
        done(this, null, null);
      }
    }
    Transform.prototype.push = function(chunk, encoding) {
      this._transformState.needTransform = false;
      return Duplex.prototype.push.call(this, chunk, encoding);
    };
    Transform.prototype._transform = function(chunk, encoding, cb) {
      cb(new ERR_METHOD_NOT_IMPLEMENTED("_transform()"));
    };
    Transform.prototype._write = function(chunk, encoding, cb) {
      var ts = this._transformState;
      ts.writecb = cb;
      ts.writechunk = chunk;
      ts.writeencoding = encoding;
      if (!ts.transforming) {
        var rs = this._readableState;
        if (ts.needTransform || rs.needReadable || rs.length < rs.highWaterMark) this._read(rs.highWaterMark);
      }
    };
    Transform.prototype._read = function(n) {
      var ts = this._transformState;
      if (ts.writechunk !== null && !ts.transforming) {
        ts.transforming = true;
        this._transform(ts.writechunk, ts.writeencoding, ts.afterTransform);
      } else {
        ts.needTransform = true;
      }
    };
    Transform.prototype._destroy = function(err, cb) {
      Duplex.prototype._destroy.call(this, err, function(err2) {
        cb(err2);
      });
    };
    function done(stream, er, data) {
      if (er) return stream.emit("error", er);
      if (data != null)
        stream.push(data);
      if (stream._writableState.length) throw new ERR_TRANSFORM_WITH_LENGTH_0();
      if (stream._transformState.transforming) throw new ERR_TRANSFORM_ALREADY_TRANSFORMING();
      return stream.push(null);
    }
  }
});

// node_modules/readable-stream/lib/_stream_passthrough.js
var require_stream_passthrough = __commonJS({
  "node_modules/readable-stream/lib/_stream_passthrough.js"(exports2, module2) {
    "use strict";
    module2.exports = PassThrough;
    var Transform = require_stream_transform();
    require_inherits()(PassThrough, Transform);
    function PassThrough(options) {
      if (!(this instanceof PassThrough)) return new PassThrough(options);
      Transform.call(this, options);
    }
    PassThrough.prototype._transform = function(chunk, encoding, cb) {
      cb(null, chunk);
    };
  }
});

// node_modules/readable-stream/lib/internal/streams/pipeline.js
var require_pipeline = __commonJS({
  "node_modules/readable-stream/lib/internal/streams/pipeline.js"(exports2, module2) {
    "use strict";
    var eos;
    function once(callback) {
      var called = false;
      return function() {
        if (called) return;
        called = true;
        callback.apply(void 0, arguments);
      };
    }
    var _require$codes = require_errors2().codes;
    var ERR_MISSING_ARGS = _require$codes.ERR_MISSING_ARGS;
    var ERR_STREAM_DESTROYED = _require$codes.ERR_STREAM_DESTROYED;
    function noop(err) {
      if (err) throw err;
    }
    function isRequest(stream) {
      return stream.setHeader && typeof stream.abort === "function";
    }
    function destroyer(stream, reading, writing, callback) {
      callback = once(callback);
      var closed = false;
      stream.on("close", function() {
        closed = true;
      });
      if (eos === void 0) eos = require_end_of_stream();
      eos(stream, {
        readable: reading,
        writable: writing
      }, function(err) {
        if (err) return callback(err);
        closed = true;
        callback();
      });
      var destroyed = false;
      return function(err) {
        if (closed) return;
        if (destroyed) return;
        destroyed = true;
        if (isRequest(stream)) return stream.abort();
        if (typeof stream.destroy === "function") return stream.destroy();
        callback(err || new ERR_STREAM_DESTROYED("pipe"));
      };
    }
    function call(fn) {
      fn();
    }
    function pipe(from, to) {
      return from.pipe(to);
    }
    function popCallback(streams) {
      if (!streams.length) return noop;
      if (typeof streams[streams.length - 1] !== "function") return noop;
      return streams.pop();
    }
    function pipeline() {
      for (var _len = arguments.length, streams = new Array(_len), _key = 0; _key < _len; _key++) {
        streams[_key] = arguments[_key];
      }
      var callback = popCallback(streams);
      if (Array.isArray(streams[0])) streams = streams[0];
      if (streams.length < 2) {
        throw new ERR_MISSING_ARGS("streams");
      }
      var error;
      var destroys = streams.map(function(stream, i) {
        var reading = i < streams.length - 1;
        var writing = i > 0;
        return destroyer(stream, reading, writing, function(err) {
          if (!error) error = err;
          if (err) destroys.forEach(call);
          if (reading) return;
          destroys.forEach(call);
          callback(error);
        });
      });
      return streams.reduce(pipe);
    }
    module2.exports = pipeline;
  }
});

// node_modules/readable-stream/readable.js
var require_readable = __commonJS({
  "node_modules/readable-stream/readable.js"(exports2, module2) {
    var Stream = require("stream");
    if (process.env.READABLE_STREAM === "disable" && Stream) {
      module2.exports = Stream.Readable;
      Object.assign(module2.exports, Stream);
      module2.exports.Stream = Stream;
    } else {
      exports2 = module2.exports = require_stream_readable();
      exports2.Stream = Stream || exports2;
      exports2.Readable = exports2;
      exports2.Writable = require_stream_writable();
      exports2.Duplex = require_stream_duplex();
      exports2.Transform = require_stream_transform();
      exports2.PassThrough = require_stream_passthrough();
      exports2.finished = require_end_of_stream();
      exports2.pipeline = require_pipeline();
    }
  }
});

// node_modules/@dabh/diagnostics/diagnostics.js
var require_diagnostics = __commonJS({
  "node_modules/@dabh/diagnostics/diagnostics.js"(exports2, module2) {
    var adapters = [];
    var modifiers = [];
    var logger3 = function devnull() {
    };
    function use(adapter) {
      if (~adapters.indexOf(adapter)) return false;
      adapters.push(adapter);
      return true;
    }
    function set(custom) {
      logger3 = custom;
    }
    function enabled(namespace) {
      var async = [];
      for (var i = 0; i < adapters.length; i++) {
        if (adapters[i].async) {
          async.push(adapters[i]);
          continue;
        }
        if (adapters[i](namespace)) return true;
      }
      if (!async.length) return false;
      return new Promise(function pinky(resolve) {
        Promise.all(
          async.map(function prebind(fn) {
            return fn(namespace);
          })
        ).then(function resolved(values) {
          resolve(values.some(Boolean));
        });
      });
    }
    function modify(fn) {
      if (~modifiers.indexOf(fn)) return false;
      modifiers.push(fn);
      return true;
    }
    function write() {
      logger3.apply(logger3, arguments);
    }
    function process2(message) {
      for (var i = 0; i < modifiers.length; i++) {
        message = modifiers[i].apply(modifiers[i], arguments);
      }
      return message;
    }
    function introduce(fn, options) {
      var has = Object.prototype.hasOwnProperty;
      for (var key in options) {
        if (has.call(options, key)) {
          fn[key] = options[key];
        }
      }
      return fn;
    }
    function nope(options) {
      options.enabled = false;
      options.modify = modify;
      options.set = set;
      options.use = use;
      return introduce(function diagnopes() {
        return false;
      }, options);
    }
    function yep(options) {
      function diagnostics() {
        var args = Array.prototype.slice.call(arguments, 0);
        write.call(write, options, process2(args, options));
        return true;
      }
      options.enabled = true;
      options.modify = modify;
      options.set = set;
      options.use = use;
      return introduce(diagnostics, options);
    }
    module2.exports = function create(diagnostics) {
      diagnostics.introduce = introduce;
      diagnostics.enabled = enabled;
      diagnostics.process = process2;
      diagnostics.modify = modify;
      diagnostics.write = write;
      diagnostics.nope = nope;
      diagnostics.yep = yep;
      diagnostics.set = set;
      diagnostics.use = use;
      return diagnostics;
    };
  }
});

// node_modules/@dabh/diagnostics/node/production.js
var require_production = __commonJS({
  "node_modules/@dabh/diagnostics/node/production.js"(exports2, module2) {
    var create = require_diagnostics();
    var diagnostics = create(function prod(namespace, options) {
      options = options || {};
      options.namespace = namespace;
      options.prod = true;
      options.dev = false;
      if (!(options.force || prod.force)) return prod.nope(options);
      return prod.yep(options);
    });
    module2.exports = diagnostics;
  }
});

// node_modules/@so-ric/colorspace/dist/index.cjs.js
var require_index_cjs = __commonJS({
  "node_modules/@so-ric/colorspace/dist/index.cjs.js"(exports2, module2) {
    "use strict";
    var cssKeywords = {
      aliceblue: [240, 248, 255],
      antiquewhite: [250, 235, 215],
      aqua: [0, 255, 255],
      aquamarine: [127, 255, 212],
      azure: [240, 255, 255],
      beige: [245, 245, 220],
      bisque: [255, 228, 196],
      black: [0, 0, 0],
      blanchedalmond: [255, 235, 205],
      blue: [0, 0, 255],
      blueviolet: [138, 43, 226],
      brown: [165, 42, 42],
      burlywood: [222, 184, 135],
      cadetblue: [95, 158, 160],
      chartreuse: [127, 255, 0],
      chocolate: [210, 105, 30],
      coral: [255, 127, 80],
      cornflowerblue: [100, 149, 237],
      cornsilk: [255, 248, 220],
      crimson: [220, 20, 60],
      cyan: [0, 255, 255],
      darkblue: [0, 0, 139],
      darkcyan: [0, 139, 139],
      darkgoldenrod: [184, 134, 11],
      darkgray: [169, 169, 169],
      darkgreen: [0, 100, 0],
      darkgrey: [169, 169, 169],
      darkkhaki: [189, 183, 107],
      darkmagenta: [139, 0, 139],
      darkolivegreen: [85, 107, 47],
      darkorange: [255, 140, 0],
      darkorchid: [153, 50, 204],
      darkred: [139, 0, 0],
      darksalmon: [233, 150, 122],
      darkseagreen: [143, 188, 143],
      darkslateblue: [72, 61, 139],
      darkslategray: [47, 79, 79],
      darkslategrey: [47, 79, 79],
      darkturquoise: [0, 206, 209],
      darkviolet: [148, 0, 211],
      deeppink: [255, 20, 147],
      deepskyblue: [0, 191, 255],
      dimgray: [105, 105, 105],
      dimgrey: [105, 105, 105],
      dodgerblue: [30, 144, 255],
      firebrick: [178, 34, 34],
      floralwhite: [255, 250, 240],
      forestgreen: [34, 139, 34],
      fuchsia: [255, 0, 255],
      gainsboro: [220, 220, 220],
      ghostwhite: [248, 248, 255],
      gold: [255, 215, 0],
      goldenrod: [218, 165, 32],
      gray: [128, 128, 128],
      green: [0, 128, 0],
      greenyellow: [173, 255, 47],
      grey: [128, 128, 128],
      honeydew: [240, 255, 240],
      hotpink: [255, 105, 180],
      indianred: [205, 92, 92],
      indigo: [75, 0, 130],
      ivory: [255, 255, 240],
      khaki: [240, 230, 140],
      lavender: [230, 230, 250],
      lavenderblush: [255, 240, 245],
      lawngreen: [124, 252, 0],
      lemonchiffon: [255, 250, 205],
      lightblue: [173, 216, 230],
      lightcoral: [240, 128, 128],
      lightcyan: [224, 255, 255],
      lightgoldenrodyellow: [250, 250, 210],
      lightgray: [211, 211, 211],
      lightgreen: [144, 238, 144],
      lightgrey: [211, 211, 211],
      lightpink: [255, 182, 193],
      lightsalmon: [255, 160, 122],
      lightseagreen: [32, 178, 170],
      lightskyblue: [135, 206, 250],
      lightslategray: [119, 136, 153],
      lightslategrey: [119, 136, 153],
      lightsteelblue: [176, 196, 222],
      lightyellow: [255, 255, 224],
      lime: [0, 255, 0],
      limegreen: [50, 205, 50],
      linen: [250, 240, 230],
      magenta: [255, 0, 255],
      maroon: [128, 0, 0],
      mediumaquamarine: [102, 205, 170],
      mediumblue: [0, 0, 205],
      mediumorchid: [186, 85, 211],
      mediumpurple: [147, 112, 219],
      mediumseagreen: [60, 179, 113],
      mediumslateblue: [123, 104, 238],
      mediumspringgreen: [0, 250, 154],
      mediumturquoise: [72, 209, 204],
      mediumvioletred: [199, 21, 133],
      midnightblue: [25, 25, 112],
      mintcream: [245, 255, 250],
      mistyrose: [255, 228, 225],
      moccasin: [255, 228, 181],
      navajowhite: [255, 222, 173],
      navy: [0, 0, 128],
      oldlace: [253, 245, 230],
      olive: [128, 128, 0],
      olivedrab: [107, 142, 35],
      orange: [255, 165, 0],
      orangered: [255, 69, 0],
      orchid: [218, 112, 214],
      palegoldenrod: [238, 232, 170],
      palegreen: [152, 251, 152],
      paleturquoise: [175, 238, 238],
      palevioletred: [219, 112, 147],
      papayawhip: [255, 239, 213],
      peachpuff: [255, 218, 185],
      peru: [205, 133, 63],
      pink: [255, 192, 203],
      plum: [221, 160, 221],
      powderblue: [176, 224, 230],
      purple: [128, 0, 128],
      rebeccapurple: [102, 51, 153],
      red: [255, 0, 0],
      rosybrown: [188, 143, 143],
      royalblue: [65, 105, 225],
      saddlebrown: [139, 69, 19],
      salmon: [250, 128, 114],
      sandybrown: [244, 164, 96],
      seagreen: [46, 139, 87],
      seashell: [255, 245, 238],
      sienna: [160, 82, 45],
      silver: [192, 192, 192],
      skyblue: [135, 206, 235],
      slateblue: [106, 90, 205],
      slategray: [112, 128, 144],
      slategrey: [112, 128, 144],
      snow: [255, 250, 250],
      springgreen: [0, 255, 127],
      steelblue: [70, 130, 180],
      tan: [210, 180, 140],
      teal: [0, 128, 128],
      thistle: [216, 191, 216],
      tomato: [255, 99, 71],
      turquoise: [64, 224, 208],
      violet: [238, 130, 238],
      wheat: [245, 222, 179],
      white: [255, 255, 255],
      whitesmoke: [245, 245, 245],
      yellow: [255, 255, 0],
      yellowgreen: [154, 205, 50]
    };
    var reverseNames = /* @__PURE__ */ Object.create(null);
    for (const name in cssKeywords) {
      if (Object.hasOwn(cssKeywords, name)) {
        reverseNames[cssKeywords[name]] = name;
      }
    }
    var cs = {
      to: {},
      get: {}
    };
    cs.get = function(string) {
      const prefix = string.slice(0, 3).toLowerCase();
      let value;
      let model;
      switch (prefix) {
        case "hsl": {
          value = cs.get.hsl(string);
          model = "hsl";
          break;
        }
        case "hwb": {
          value = cs.get.hwb(string);
          model = "hwb";
          break;
        }
        default: {
          value = cs.get.rgb(string);
          model = "rgb";
          break;
        }
      }
      if (!value) {
        return null;
      }
      return { model, value };
    };
    cs.get.rgb = function(string) {
      if (!string) {
        return null;
      }
      const abbr = /^#([a-f\d]{3,4})$/i;
      const hex2 = /^#([a-f\d]{6})([a-f\d]{2})?$/i;
      const rgba = /^rgba?\(\s*([+-]?\d+)(?=[\s,])\s*(?:,\s*)?([+-]?\d+)(?=[\s,])\s*(?:,\s*)?([+-]?\d+)\s*(?:[\s,|/]\s*([+-]?[\d.]+)(%?)\s*)?\)$/;
      const per = /^rgba?\(\s*([+-]?[\d.]+)%\s*,?\s*([+-]?[\d.]+)%\s*,?\s*([+-]?[\d.]+)%\s*(?:[\s,|/]\s*([+-]?[\d.]+)(%?)\s*)?\)$/;
      const keyword = /^(\w+)$/;
      let rgb = [0, 0, 0, 1];
      let match;
      let i;
      let hexAlpha;
      if (match = string.match(hex2)) {
        hexAlpha = match[2];
        match = match[1];
        for (i = 0; i < 3; i++) {
          const i2 = i * 2;
          rgb[i] = Number.parseInt(match.slice(i2, i2 + 2), 16);
        }
        if (hexAlpha) {
          rgb[3] = Number.parseInt(hexAlpha, 16) / 255;
        }
      } else if (match = string.match(abbr)) {
        match = match[1];
        hexAlpha = match[3];
        for (i = 0; i < 3; i++) {
          rgb[i] = Number.parseInt(match[i] + match[i], 16);
        }
        if (hexAlpha) {
          rgb[3] = Number.parseInt(hexAlpha + hexAlpha, 16) / 255;
        }
      } else if (match = string.match(rgba)) {
        for (i = 0; i < 3; i++) {
          rgb[i] = Number.parseInt(match[i + 1], 10);
        }
        if (match[4]) {
          rgb[3] = match[5] ? Number.parseFloat(match[4]) * 0.01 : Number.parseFloat(match[4]);
        }
      } else if (match = string.match(per)) {
        for (i = 0; i < 3; i++) {
          rgb[i] = Math.round(Number.parseFloat(match[i + 1]) * 2.55);
        }
        if (match[4]) {
          rgb[3] = match[5] ? Number.parseFloat(match[4]) * 0.01 : Number.parseFloat(match[4]);
        }
      } else if (match = string.match(keyword)) {
        if (match[1] === "transparent") {
          return [0, 0, 0, 0];
        }
        if (!Object.hasOwn(cssKeywords, match[1])) {
          return null;
        }
        rgb = cssKeywords[match[1]];
        rgb[3] = 1;
        return rgb;
      } else {
        return null;
      }
      for (i = 0; i < 3; i++) {
        rgb[i] = clamp(rgb[i], 0, 255);
      }
      rgb[3] = clamp(rgb[3], 0, 1);
      return rgb;
    };
    cs.get.hsl = function(string) {
      if (!string) {
        return null;
      }
      const hsl = /^hsla?\(\s*([+-]?(?:\d{0,3}\.)?\d+)(?:deg)?\s*,?\s*([+-]?[\d.]+)%\s*,?\s*([+-]?[\d.]+)%\s*(?:[,|/]\s*([+-]?(?=\.\d|\d)(?:0|[1-9]\d*)?(?:\.\d*)?(?:[eE][+-]?\d+)?)\s*)?\)$/;
      const match = string.match(hsl);
      if (match) {
        const alpha = Number.parseFloat(match[4]);
        const h = (Number.parseFloat(match[1]) % 360 + 360) % 360;
        const s = clamp(Number.parseFloat(match[2]), 0, 100);
        const l = clamp(Number.parseFloat(match[3]), 0, 100);
        const a = clamp(Number.isNaN(alpha) ? 1 : alpha, 0, 1);
        return [h, s, l, a];
      }
      return null;
    };
    cs.get.hwb = function(string) {
      if (!string) {
        return null;
      }
      const hwb = /^hwb\(\s*([+-]?\d{0,3}(?:\.\d+)?)(?:deg)?\s*[\s,]\s*([+-]?[\d.]+)%\s*[\s,]\s*([+-]?[\d.]+)%\s*(?:[\s,]\s*([+-]?(?=\.\d|\d)(?:0|[1-9]\d*)?(?:\.\d*)?(?:[eE][+-]?\d+)?)\s*)?\)$/;
      const match = string.match(hwb);
      if (match) {
        const alpha = Number.parseFloat(match[4]);
        const h = (Number.parseFloat(match[1]) % 360 + 360) % 360;
        const w = clamp(Number.parseFloat(match[2]), 0, 100);
        const b = clamp(Number.parseFloat(match[3]), 0, 100);
        const a = clamp(Number.isNaN(alpha) ? 1 : alpha, 0, 1);
        return [h, w, b, a];
      }
      return null;
    };
    cs.to.hex = function(...rgba) {
      return "#" + hexDouble(rgba[0]) + hexDouble(rgba[1]) + hexDouble(rgba[2]) + (rgba[3] < 1 ? hexDouble(Math.round(rgba[3] * 255)) : "");
    };
    cs.to.rgb = function(...rgba) {
      return rgba.length < 4 || rgba[3] === 1 ? "rgb(" + Math.round(rgba[0]) + ", " + Math.round(rgba[1]) + ", " + Math.round(rgba[2]) + ")" : "rgba(" + Math.round(rgba[0]) + ", " + Math.round(rgba[1]) + ", " + Math.round(rgba[2]) + ", " + rgba[3] + ")";
    };
    cs.to.rgb.percent = function(...rgba) {
      const r = Math.round(rgba[0] / 255 * 100);
      const g = Math.round(rgba[1] / 255 * 100);
      const b = Math.round(rgba[2] / 255 * 100);
      return rgba.length < 4 || rgba[3] === 1 ? "rgb(" + r + "%, " + g + "%, " + b + "%)" : "rgba(" + r + "%, " + g + "%, " + b + "%, " + rgba[3] + ")";
    };
    cs.to.hsl = function(...hsla) {
      return hsla.length < 4 || hsla[3] === 1 ? "hsl(" + hsla[0] + ", " + hsla[1] + "%, " + hsla[2] + "%)" : "hsla(" + hsla[0] + ", " + hsla[1] + "%, " + hsla[2] + "%, " + hsla[3] + ")";
    };
    cs.to.hwb = function(...hwba) {
      let a = "";
      if (hwba.length >= 4 && hwba[3] !== 1) {
        a = ", " + hwba[3];
      }
      return "hwb(" + hwba[0] + ", " + hwba[1] + "%, " + hwba[2] + "%" + a + ")";
    };
    cs.to.keyword = function(...rgb) {
      return reverseNames[rgb.slice(0, 3)];
    };
    function clamp(number_, min, max) {
      return Math.min(Math.max(min, number_), max);
    }
    function hexDouble(number_) {
      const string_ = Math.round(number_).toString(16).toUpperCase();
      return string_.length < 2 ? "0" + string_ : string_;
    }
    var reverseKeywords = {};
    for (const key of Object.keys(cssKeywords)) {
      reverseKeywords[cssKeywords[key]] = key;
    }
    var convert$1 = {
      rgb: { channels: 3, labels: "rgb" },
      hsl: { channels: 3, labels: "hsl" },
      hsv: { channels: 3, labels: "hsv" },
      hwb: { channels: 3, labels: "hwb" },
      cmyk: { channels: 4, labels: "cmyk" },
      xyz: { channels: 3, labels: "xyz" },
      lab: { channels: 3, labels: "lab" },
      oklab: { channels: 3, labels: ["okl", "oka", "okb"] },
      lch: { channels: 3, labels: "lch" },
      oklch: { channels: 3, labels: ["okl", "okc", "okh"] },
      hex: { channels: 1, labels: ["hex"] },
      keyword: { channels: 1, labels: ["keyword"] },
      ansi16: { channels: 1, labels: ["ansi16"] },
      ansi256: { channels: 1, labels: ["ansi256"] },
      hcg: { channels: 3, labels: ["h", "c", "g"] },
      apple: { channels: 3, labels: ["r16", "g16", "b16"] },
      gray: { channels: 1, labels: ["gray"] }
    };
    var LAB_FT = (6 / 29) ** 3;
    function srgbNonlinearTransform(c) {
      const cc = c > 31308e-7 ? 1.055 * c ** (1 / 2.4) - 0.055 : c * 12.92;
      return Math.min(Math.max(0, cc), 1);
    }
    function srgbNonlinearTransformInv(c) {
      return c > 0.04045 ? ((c + 0.055) / 1.055) ** 2.4 : c / 12.92;
    }
    for (const model of Object.keys(convert$1)) {
      if (!("channels" in convert$1[model])) {
        throw new Error("missing channels property: " + model);
      }
      if (!("labels" in convert$1[model])) {
        throw new Error("missing channel labels property: " + model);
      }
      if (convert$1[model].labels.length !== convert$1[model].channels) {
        throw new Error("channel and label counts mismatch: " + model);
      }
      const { channels, labels } = convert$1[model];
      delete convert$1[model].channels;
      delete convert$1[model].labels;
      Object.defineProperty(convert$1[model], "channels", { value: channels });
      Object.defineProperty(convert$1[model], "labels", { value: labels });
    }
    convert$1.rgb.hsl = function(rgb) {
      const r = rgb[0] / 255;
      const g = rgb[1] / 255;
      const b = rgb[2] / 255;
      const min = Math.min(r, g, b);
      const max = Math.max(r, g, b);
      const delta = max - min;
      let h;
      let s;
      switch (max) {
        case min: {
          h = 0;
          break;
        }
        case r: {
          h = (g - b) / delta;
          break;
        }
        case g: {
          h = 2 + (b - r) / delta;
          break;
        }
        case b: {
          h = 4 + (r - g) / delta;
          break;
        }
      }
      h = Math.min(h * 60, 360);
      if (h < 0) {
        h += 360;
      }
      const l = (min + max) / 2;
      if (max === min) {
        s = 0;
      } else if (l <= 0.5) {
        s = delta / (max + min);
      } else {
        s = delta / (2 - max - min);
      }
      return [h, s * 100, l * 100];
    };
    convert$1.rgb.hsv = function(rgb) {
      let rdif;
      let gdif;
      let bdif;
      let h;
      let s;
      const r = rgb[0] / 255;
      const g = rgb[1] / 255;
      const b = rgb[2] / 255;
      const v = Math.max(r, g, b);
      const diff = v - Math.min(r, g, b);
      const diffc = function(c) {
        return (v - c) / 6 / diff + 1 / 2;
      };
      if (diff === 0) {
        h = 0;
        s = 0;
      } else {
        s = diff / v;
        rdif = diffc(r);
        gdif = diffc(g);
        bdif = diffc(b);
        switch (v) {
          case r: {
            h = bdif - gdif;
            break;
          }
          case g: {
            h = 1 / 3 + rdif - bdif;
            break;
          }
          case b: {
            h = 2 / 3 + gdif - rdif;
            break;
          }
        }
        if (h < 0) {
          h += 1;
        } else if (h > 1) {
          h -= 1;
        }
      }
      return [
        h * 360,
        s * 100,
        v * 100
      ];
    };
    convert$1.rgb.hwb = function(rgb) {
      const r = rgb[0];
      const g = rgb[1];
      let b = rgb[2];
      const h = convert$1.rgb.hsl(rgb)[0];
      const w = 1 / 255 * Math.min(r, Math.min(g, b));
      b = 1 - 1 / 255 * Math.max(r, Math.max(g, b));
      return [h, w * 100, b * 100];
    };
    convert$1.rgb.oklab = function(rgb) {
      const r = srgbNonlinearTransformInv(rgb[0] / 255);
      const g = srgbNonlinearTransformInv(rgb[1] / 255);
      const b = srgbNonlinearTransformInv(rgb[2] / 255);
      const lp = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
      const mp = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
      const sp = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
      const l = 0.2104542553 * lp + 0.793617785 * mp - 0.0040720468 * sp;
      const aa = 1.9779984951 * lp - 2.428592205 * mp + 0.4505937099 * sp;
      const bb = 0.0259040371 * lp + 0.7827717662 * mp - 0.808675766 * sp;
      return [l * 100, aa * 100, bb * 100];
    };
    convert$1.rgb.cmyk = function(rgb) {
      const r = rgb[0] / 255;
      const g = rgb[1] / 255;
      const b = rgb[2] / 255;
      const k = Math.min(1 - r, 1 - g, 1 - b);
      const c = (1 - r - k) / (1 - k) || 0;
      const m = (1 - g - k) / (1 - k) || 0;
      const y = (1 - b - k) / (1 - k) || 0;
      return [c * 100, m * 100, y * 100, k * 100];
    };
    function comparativeDistance(x, y) {
      return (x[0] - y[0]) ** 2 + (x[1] - y[1]) ** 2 + (x[2] - y[2]) ** 2;
    }
    convert$1.rgb.keyword = function(rgb) {
      const reversed = reverseKeywords[rgb];
      if (reversed) {
        return reversed;
      }
      let currentClosestDistance = Number.POSITIVE_INFINITY;
      let currentClosestKeyword;
      for (const keyword of Object.keys(cssKeywords)) {
        const value = cssKeywords[keyword];
        const distance = comparativeDistance(rgb, value);
        if (distance < currentClosestDistance) {
          currentClosestDistance = distance;
          currentClosestKeyword = keyword;
        }
      }
      return currentClosestKeyword;
    };
    convert$1.keyword.rgb = function(keyword) {
      return cssKeywords[keyword];
    };
    convert$1.rgb.xyz = function(rgb) {
      const r = srgbNonlinearTransformInv(rgb[0] / 255);
      const g = srgbNonlinearTransformInv(rgb[1] / 255);
      const b = srgbNonlinearTransformInv(rgb[2] / 255);
      const x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375;
      const y = r * 0.2126729 + g * 0.7151522 + b * 0.072175;
      const z = r * 0.0193339 + g * 0.119192 + b * 0.9503041;
      return [x * 100, y * 100, z * 100];
    };
    convert$1.rgb.lab = function(rgb) {
      const xyz = convert$1.rgb.xyz(rgb);
      let x = xyz[0];
      let y = xyz[1];
      let z = xyz[2];
      x /= 95.047;
      y /= 100;
      z /= 108.883;
      x = x > LAB_FT ? x ** (1 / 3) : 7.787 * x + 16 / 116;
      y = y > LAB_FT ? y ** (1 / 3) : 7.787 * y + 16 / 116;
      z = z > LAB_FT ? z ** (1 / 3) : 7.787 * z + 16 / 116;
      const l = 116 * y - 16;
      const a = 500 * (x - y);
      const b = 200 * (y - z);
      return [l, a, b];
    };
    convert$1.hsl.rgb = function(hsl) {
      const h = hsl[0] / 360;
      const s = hsl[1] / 100;
      const l = hsl[2] / 100;
      let t3;
      let value;
      if (s === 0) {
        value = l * 255;
        return [value, value, value];
      }
      const t2 = l < 0.5 ? l * (1 + s) : l + s - l * s;
      const t1 = 2 * l - t2;
      const rgb = [0, 0, 0];
      for (let i = 0; i < 3; i++) {
        t3 = h + 1 / 3 * -(i - 1);
        if (t3 < 0) {
          t3++;
        }
        if (t3 > 1) {
          t3--;
        }
        if (6 * t3 < 1) {
          value = t1 + (t2 - t1) * 6 * t3;
        } else if (2 * t3 < 1) {
          value = t2;
        } else if (3 * t3 < 2) {
          value = t1 + (t2 - t1) * (2 / 3 - t3) * 6;
        } else {
          value = t1;
        }
        rgb[i] = value * 255;
      }
      return rgb;
    };
    convert$1.hsl.hsv = function(hsl) {
      const h = hsl[0];
      let s = hsl[1] / 100;
      let l = hsl[2] / 100;
      let smin = s;
      const lmin = Math.max(l, 0.01);
      l *= 2;
      s *= l <= 1 ? l : 2 - l;
      smin *= lmin <= 1 ? lmin : 2 - lmin;
      const v = (l + s) / 2;
      const sv = l === 0 ? 2 * smin / (lmin + smin) : 2 * s / (l + s);
      return [h, sv * 100, v * 100];
    };
    convert$1.hsv.rgb = function(hsv) {
      const h = hsv[0] / 60;
      const s = hsv[1] / 100;
      let v = hsv[2] / 100;
      const hi = Math.floor(h) % 6;
      const f = h - Math.floor(h);
      const p = 255 * v * (1 - s);
      const q = 255 * v * (1 - s * f);
      const t = 255 * v * (1 - s * (1 - f));
      v *= 255;
      switch (hi) {
        case 0: {
          return [v, t, p];
        }
        case 1: {
          return [q, v, p];
        }
        case 2: {
          return [p, v, t];
        }
        case 3: {
          return [p, q, v];
        }
        case 4: {
          return [t, p, v];
        }
        case 5: {
          return [v, p, q];
        }
      }
    };
    convert$1.hsv.hsl = function(hsv) {
      const h = hsv[0];
      const s = hsv[1] / 100;
      const v = hsv[2] / 100;
      const vmin = Math.max(v, 0.01);
      let sl;
      let l;
      l = (2 - s) * v;
      const lmin = (2 - s) * vmin;
      sl = s * vmin;
      sl /= lmin <= 1 ? lmin : 2 - lmin;
      sl = sl || 0;
      l /= 2;
      return [h, sl * 100, l * 100];
    };
    convert$1.hwb.rgb = function(hwb) {
      const h = hwb[0] / 360;
      let wh = hwb[1] / 100;
      let bl = hwb[2] / 100;
      const ratio = wh + bl;
      let f;
      if (ratio > 1) {
        wh /= ratio;
        bl /= ratio;
      }
      const i = Math.floor(6 * h);
      const v = 1 - bl;
      f = 6 * h - i;
      if ((i & 1) !== 0) {
        f = 1 - f;
      }
      const n = wh + f * (v - wh);
      let r;
      let g;
      let b;
      switch (i) {
        default:
        case 6:
        case 0: {
          r = v;
          g = n;
          b = wh;
          break;
        }
        case 1: {
          r = n;
          g = v;
          b = wh;
          break;
        }
        case 2: {
          r = wh;
          g = v;
          b = n;
          break;
        }
        case 3: {
          r = wh;
          g = n;
          b = v;
          break;
        }
        case 4: {
          r = n;
          g = wh;
          b = v;
          break;
        }
        case 5: {
          r = v;
          g = wh;
          b = n;
          break;
        }
      }
      return [r * 255, g * 255, b * 255];
    };
    convert$1.cmyk.rgb = function(cmyk) {
      const c = cmyk[0] / 100;
      const m = cmyk[1] / 100;
      const y = cmyk[2] / 100;
      const k = cmyk[3] / 100;
      const r = 1 - Math.min(1, c * (1 - k) + k);
      const g = 1 - Math.min(1, m * (1 - k) + k);
      const b = 1 - Math.min(1, y * (1 - k) + k);
      return [r * 255, g * 255, b * 255];
    };
    convert$1.xyz.rgb = function(xyz) {
      const x = xyz[0] / 100;
      const y = xyz[1] / 100;
      const z = xyz[2] / 100;
      let r;
      let g;
      let b;
      r = x * 3.2404542 + y * -1.5371385 + z * -0.4985314;
      g = x * -0.969266 + y * 1.8760108 + z * 0.041556;
      b = x * 0.0556434 + y * -0.2040259 + z * 1.0572252;
      r = srgbNonlinearTransform(r);
      g = srgbNonlinearTransform(g);
      b = srgbNonlinearTransform(b);
      return [r * 255, g * 255, b * 255];
    };
    convert$1.xyz.lab = function(xyz) {
      let x = xyz[0];
      let y = xyz[1];
      let z = xyz[2];
      x /= 95.047;
      y /= 100;
      z /= 108.883;
      x = x > LAB_FT ? x ** (1 / 3) : 7.787 * x + 16 / 116;
      y = y > LAB_FT ? y ** (1 / 3) : 7.787 * y + 16 / 116;
      z = z > LAB_FT ? z ** (1 / 3) : 7.787 * z + 16 / 116;
      const l = 116 * y - 16;
      const a = 500 * (x - y);
      const b = 200 * (y - z);
      return [l, a, b];
    };
    convert$1.xyz.oklab = function(xyz) {
      const x = xyz[0] / 100;
      const y = xyz[1] / 100;
      const z = xyz[2] / 100;
      const lp = Math.cbrt(0.8189330101 * x + 0.3618667424 * y - 0.1288597137 * z);
      const mp = Math.cbrt(0.0329845436 * x + 0.9293118715 * y + 0.0361456387 * z);
      const sp = Math.cbrt(0.0482003018 * x + 0.2643662691 * y + 0.633851707 * z);
      const l = 0.2104542553 * lp + 0.793617785 * mp - 0.0040720468 * sp;
      const a = 1.9779984951 * lp - 2.428592205 * mp + 0.4505937099 * sp;
      const b = 0.0259040371 * lp + 0.7827717662 * mp - 0.808675766 * sp;
      return [l * 100, a * 100, b * 100];
    };
    convert$1.oklab.oklch = function(oklab) {
      return convert$1.lab.lch(oklab);
    };
    convert$1.oklab.xyz = function(oklab) {
      const ll = oklab[0] / 100;
      const a = oklab[1] / 100;
      const b = oklab[2] / 100;
      const l = (0.999999998 * ll + 0.396337792 * a + 0.215803758 * b) ** 3;
      const m = (1.000000008 * ll - 0.105561342 * a - 0.063854175 * b) ** 3;
      const s = (1.000000055 * ll - 0.089484182 * a - 1.291485538 * b) ** 3;
      const x = 1.227013851 * l - 0.55779998 * m + 0.281256149 * s;
      const y = -0.040580178 * l + 1.11225687 * m - 0.071676679 * s;
      const z = -0.076381285 * l - 0.421481978 * m + 1.58616322 * s;
      return [x * 100, y * 100, z * 100];
    };
    convert$1.oklab.rgb = function(oklab) {
      const ll = oklab[0] / 100;
      const aa = oklab[1] / 100;
      const bb = oklab[2] / 100;
      const l = (ll + 0.3963377774 * aa + 0.2158037573 * bb) ** 3;
      const m = (ll - 0.1055613458 * aa - 0.0638541728 * bb) ** 3;
      const s = (ll - 0.0894841775 * aa - 1.291485548 * bb) ** 3;
      const r = srgbNonlinearTransform(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s);
      const g = srgbNonlinearTransform(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s);
      const b = srgbNonlinearTransform(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s);
      return [r * 255, g * 255, b * 255];
    };
    convert$1.oklch.oklab = function(oklch) {
      return convert$1.lch.lab(oklch);
    };
    convert$1.lab.xyz = function(lab) {
      const l = lab[0];
      const a = lab[1];
      const b = lab[2];
      let x;
      let y;
      let z;
      y = (l + 16) / 116;
      x = a / 500 + y;
      z = y - b / 200;
      const y2 = y ** 3;
      const x2 = x ** 3;
      const z2 = z ** 3;
      y = y2 > LAB_FT ? y2 : (y - 16 / 116) / 7.787;
      x = x2 > LAB_FT ? x2 : (x - 16 / 116) / 7.787;
      z = z2 > LAB_FT ? z2 : (z - 16 / 116) / 7.787;
      x *= 95.047;
      y *= 100;
      z *= 108.883;
      return [x, y, z];
    };
    convert$1.lab.lch = function(lab) {
      const l = lab[0];
      const a = lab[1];
      const b = lab[2];
      let h;
      const hr = Math.atan2(b, a);
      h = hr * 360 / 2 / Math.PI;
      if (h < 0) {
        h += 360;
      }
      const c = Math.sqrt(a * a + b * b);
      return [l, c, h];
    };
    convert$1.lch.lab = function(lch) {
      const l = lch[0];
      const c = lch[1];
      const h = lch[2];
      const hr = h / 360 * 2 * Math.PI;
      const a = c * Math.cos(hr);
      const b = c * Math.sin(hr);
      return [l, a, b];
    };
    convert$1.rgb.ansi16 = function(args, saturation = null) {
      const [r, g, b] = args;
      let value = saturation === null ? convert$1.rgb.hsv(args)[2] : saturation;
      value = Math.round(value / 50);
      if (value === 0) {
        return 30;
      }
      let ansi = 30 + (Math.round(b / 255) << 2 | Math.round(g / 255) << 1 | Math.round(r / 255));
      if (value === 2) {
        ansi += 60;
      }
      return ansi;
    };
    convert$1.hsv.ansi16 = function(args) {
      return convert$1.rgb.ansi16(convert$1.hsv.rgb(args), args[2]);
    };
    convert$1.rgb.ansi256 = function(args) {
      const r = args[0];
      const g = args[1];
      const b = args[2];
      if (r >> 4 === g >> 4 && g >> 4 === b >> 4) {
        if (r < 8) {
          return 16;
        }
        if (r > 248) {
          return 231;
        }
        return Math.round((r - 8) / 247 * 24) + 232;
      }
      const ansi = 16 + 36 * Math.round(r / 255 * 5) + 6 * Math.round(g / 255 * 5) + Math.round(b / 255 * 5);
      return ansi;
    };
    convert$1.ansi16.rgb = function(args) {
      args = args[0];
      let color = args % 10;
      if (color === 0 || color === 7) {
        if (args > 50) {
          color += 3.5;
        }
        color = color / 10.5 * 255;
        return [color, color, color];
      }
      const mult = (Math.trunc(args > 50) + 1) * 0.5;
      const r = (color & 1) * mult * 255;
      const g = (color >> 1 & 1) * mult * 255;
      const b = (color >> 2 & 1) * mult * 255;
      return [r, g, b];
    };
    convert$1.ansi256.rgb = function(args) {
      args = args[0];
      if (args >= 232) {
        const c = (args - 232) * 10 + 8;
        return [c, c, c];
      }
      args -= 16;
      let rem;
      const r = Math.floor(args / 36) / 5 * 255;
      const g = Math.floor((rem = args % 36) / 6) / 5 * 255;
      const b = rem % 6 / 5 * 255;
      return [r, g, b];
    };
    convert$1.rgb.hex = function(args) {
      const integer = ((Math.round(args[0]) & 255) << 16) + ((Math.round(args[1]) & 255) << 8) + (Math.round(args[2]) & 255);
      const string = integer.toString(16).toUpperCase();
      return "000000".slice(string.length) + string;
    };
    convert$1.hex.rgb = function(args) {
      const match = args.toString(16).match(/[a-f\d]{6}|[a-f\d]{3}/i);
      if (!match) {
        return [0, 0, 0];
      }
      let colorString = match[0];
      if (match[0].length === 3) {
        colorString = [...colorString].map((char) => char + char).join("");
      }
      const integer = Number.parseInt(colorString, 16);
      const r = integer >> 16 & 255;
      const g = integer >> 8 & 255;
      const b = integer & 255;
      return [r, g, b];
    };
    convert$1.rgb.hcg = function(rgb) {
      const r = rgb[0] / 255;
      const g = rgb[1] / 255;
      const b = rgb[2] / 255;
      const max = Math.max(Math.max(r, g), b);
      const min = Math.min(Math.min(r, g), b);
      const chroma = max - min;
      let hue;
      const grayscale = chroma < 1 ? min / (1 - chroma) : 0;
      if (chroma <= 0) {
        hue = 0;
      } else if (max === r) {
        hue = (g - b) / chroma % 6;
      } else if (max === g) {
        hue = 2 + (b - r) / chroma;
      } else {
        hue = 4 + (r - g) / chroma;
      }
      hue /= 6;
      hue %= 1;
      return [hue * 360, chroma * 100, grayscale * 100];
    };
    convert$1.hsl.hcg = function(hsl) {
      const s = hsl[1] / 100;
      const l = hsl[2] / 100;
      const c = l < 0.5 ? 2 * s * l : 2 * s * (1 - l);
      let f = 0;
      if (c < 1) {
        f = (l - 0.5 * c) / (1 - c);
      }
      return [hsl[0], c * 100, f * 100];
    };
    convert$1.hsv.hcg = function(hsv) {
      const s = hsv[1] / 100;
      const v = hsv[2] / 100;
      const c = s * v;
      let f = 0;
      if (c < 1) {
        f = (v - c) / (1 - c);
      }
      return [hsv[0], c * 100, f * 100];
    };
    convert$1.hcg.rgb = function(hcg) {
      const h = hcg[0] / 360;
      const c = hcg[1] / 100;
      const g = hcg[2] / 100;
      if (c === 0) {
        return [g * 255, g * 255, g * 255];
      }
      const pure = [0, 0, 0];
      const hi = h % 1 * 6;
      const v = hi % 1;
      const w = 1 - v;
      let mg = 0;
      switch (Math.floor(hi)) {
        case 0: {
          pure[0] = 1;
          pure[1] = v;
          pure[2] = 0;
          break;
        }
        case 1: {
          pure[0] = w;
          pure[1] = 1;
          pure[2] = 0;
          break;
        }
        case 2: {
          pure[0] = 0;
          pure[1] = 1;
          pure[2] = v;
          break;
        }
        case 3: {
          pure[0] = 0;
          pure[1] = w;
          pure[2] = 1;
          break;
        }
        case 4: {
          pure[0] = v;
          pure[1] = 0;
          pure[2] = 1;
          break;
        }
        default: {
          pure[0] = 1;
          pure[1] = 0;
          pure[2] = w;
        }
      }
      mg = (1 - c) * g;
      return [
        (c * pure[0] + mg) * 255,
        (c * pure[1] + mg) * 255,
        (c * pure[2] + mg) * 255
      ];
    };
    convert$1.hcg.hsv = function(hcg) {
      const c = hcg[1] / 100;
      const g = hcg[2] / 100;
      const v = c + g * (1 - c);
      let f = 0;
      if (v > 0) {
        f = c / v;
      }
      return [hcg[0], f * 100, v * 100];
    };
    convert$1.hcg.hsl = function(hcg) {
      const c = hcg[1] / 100;
      const g = hcg[2] / 100;
      const l = g * (1 - c) + 0.5 * c;
      let s = 0;
      if (l > 0 && l < 0.5) {
        s = c / (2 * l);
      } else if (l >= 0.5 && l < 1) {
        s = c / (2 * (1 - l));
      }
      return [hcg[0], s * 100, l * 100];
    };
    convert$1.hcg.hwb = function(hcg) {
      const c = hcg[1] / 100;
      const g = hcg[2] / 100;
      const v = c + g * (1 - c);
      return [hcg[0], (v - c) * 100, (1 - v) * 100];
    };
    convert$1.hwb.hcg = function(hwb) {
      const w = hwb[1] / 100;
      const b = hwb[2] / 100;
      const v = 1 - b;
      const c = v - w;
      let g = 0;
      if (c < 1) {
        g = (v - c) / (1 - c);
      }
      return [hwb[0], c * 100, g * 100];
    };
    convert$1.apple.rgb = function(apple) {
      return [apple[0] / 65535 * 255, apple[1] / 65535 * 255, apple[2] / 65535 * 255];
    };
    convert$1.rgb.apple = function(rgb) {
      return [rgb[0] / 255 * 65535, rgb[1] / 255 * 65535, rgb[2] / 255 * 65535];
    };
    convert$1.gray.rgb = function(args) {
      return [args[0] / 100 * 255, args[0] / 100 * 255, args[0] / 100 * 255];
    };
    convert$1.gray.hsl = function(args) {
      return [0, 0, args[0]];
    };
    convert$1.gray.hsv = convert$1.gray.hsl;
    convert$1.gray.hwb = function(gray) {
      return [0, 100, gray[0]];
    };
    convert$1.gray.cmyk = function(gray) {
      return [0, 0, 0, gray[0]];
    };
    convert$1.gray.lab = function(gray) {
      return [gray[0], 0, 0];
    };
    convert$1.gray.hex = function(gray) {
      const value = Math.round(gray[0] / 100 * 255) & 255;
      const integer = (value << 16) + (value << 8) + value;
      const string = integer.toString(16).toUpperCase();
      return "000000".slice(string.length) + string;
    };
    convert$1.rgb.gray = function(rgb) {
      const value = (rgb[0] + rgb[1] + rgb[2]) / 3;
      return [value / 255 * 100];
    };
    function buildGraph() {
      const graph = {};
      const models2 = Object.keys(convert$1);
      for (let { length } = models2, i = 0; i < length; i++) {
        graph[models2[i]] = {
          // http://jsperf.com/1-vs-infinity
          // micro-opt, but this is simple.
          distance: -1,
          parent: null
        };
      }
      return graph;
    }
    function deriveBFS(fromModel) {
      const graph = buildGraph();
      const queue = [fromModel];
      graph[fromModel].distance = 0;
      while (queue.length > 0) {
        const current = queue.pop();
        const adjacents = Object.keys(convert$1[current]);
        for (let { length } = adjacents, i = 0; i < length; i++) {
          const adjacent = adjacents[i];
          const node = graph[adjacent];
          if (node.distance === -1) {
            node.distance = graph[current].distance + 1;
            node.parent = current;
            queue.unshift(adjacent);
          }
        }
      }
      return graph;
    }
    function link(from, to) {
      return function(args) {
        return to(from(args));
      };
    }
    function wrapConversion(toModel, graph) {
      const path2 = [graph[toModel].parent, toModel];
      let fn = convert$1[graph[toModel].parent][toModel];
      let cur = graph[toModel].parent;
      while (graph[cur].parent) {
        path2.unshift(graph[cur].parent);
        fn = link(convert$1[graph[cur].parent][cur], fn);
        cur = graph[cur].parent;
      }
      fn.conversion = path2;
      return fn;
    }
    function route(fromModel) {
      const graph = deriveBFS(fromModel);
      const conversion = {};
      const models2 = Object.keys(graph);
      for (let { length } = models2, i = 0; i < length; i++) {
        const toModel = models2[i];
        const node = graph[toModel];
        if (node.parent === null) {
          continue;
        }
        conversion[toModel] = wrapConversion(toModel, graph);
      }
      return conversion;
    }
    var convert = {};
    var models = Object.keys(convert$1);
    function wrapRaw(fn) {
      const wrappedFn = function(...args) {
        const arg0 = args[0];
        if (arg0 === void 0 || arg0 === null) {
          return arg0;
        }
        if (arg0.length > 1) {
          args = arg0;
        }
        return fn(args);
      };
      if ("conversion" in fn) {
        wrappedFn.conversion = fn.conversion;
      }
      return wrappedFn;
    }
    function wrapRounded(fn) {
      const wrappedFn = function(...args) {
        const arg0 = args[0];
        if (arg0 === void 0 || arg0 === null) {
          return arg0;
        }
        if (arg0.length > 1) {
          args = arg0;
        }
        const result = fn(args);
        if (typeof result === "object") {
          for (let { length } = result, i = 0; i < length; i++) {
            result[i] = Math.round(result[i]);
          }
        }
        return result;
      };
      if ("conversion" in fn) {
        wrappedFn.conversion = fn.conversion;
      }
      return wrappedFn;
    }
    for (const fromModel of models) {
      convert[fromModel] = {};
      Object.defineProperty(convert[fromModel], "channels", { value: convert$1[fromModel].channels });
      Object.defineProperty(convert[fromModel], "labels", { value: convert$1[fromModel].labels });
      const routes = route(fromModel);
      const routeModels = Object.keys(routes);
      for (const toModel of routeModels) {
        const fn = routes[toModel];
        convert[fromModel][toModel] = wrapRounded(fn);
        convert[fromModel][toModel].raw = wrapRaw(fn);
      }
    }
    var skippedModels = [
      // To be honest, I don't really feel like keyword belongs in color convert, but eh.
      "keyword",
      // Gray conflicts with some method names, and has its own method defined.
      "gray",
      // Shouldn't really be in color-convert either...
      "hex"
    ];
    var hashedModelKeys = {};
    for (const model of Object.keys(convert)) {
      hashedModelKeys[[...convert[model].labels].sort().join("")] = model;
    }
    var limiters = {};
    function Color(object, model) {
      if (!(this instanceof Color)) {
        return new Color(object, model);
      }
      if (model && model in skippedModels) {
        model = null;
      }
      if (model && !(model in convert)) {
        throw new Error("Unknown model: " + model);
      }
      let i;
      let channels;
      if (object == null) {
        this.model = "rgb";
        this.color = [0, 0, 0];
        this.valpha = 1;
      } else if (object instanceof Color) {
        this.model = object.model;
        this.color = [...object.color];
        this.valpha = object.valpha;
      } else if (typeof object === "string") {
        const result = cs.get(object);
        if (result === null) {
          throw new Error("Unable to parse color from string: " + object);
        }
        this.model = result.model;
        channels = convert[this.model].channels;
        this.color = result.value.slice(0, channels);
        this.valpha = typeof result.value[channels] === "number" ? result.value[channels] : 1;
      } else if (object.length > 0) {
        this.model = model || "rgb";
        channels = convert[this.model].channels;
        const newArray = Array.prototype.slice.call(object, 0, channels);
        this.color = zeroArray(newArray, channels);
        this.valpha = typeof object[channels] === "number" ? object[channels] : 1;
      } else if (typeof object === "number") {
        this.model = "rgb";
        this.color = [
          object >> 16 & 255,
          object >> 8 & 255,
          object & 255
        ];
        this.valpha = 1;
      } else {
        this.valpha = 1;
        const keys = Object.keys(object);
        if ("alpha" in object) {
          keys.splice(keys.indexOf("alpha"), 1);
          this.valpha = typeof object.alpha === "number" ? object.alpha : 0;
        }
        const hashedKeys = keys.sort().join("");
        if (!(hashedKeys in hashedModelKeys)) {
          throw new Error("Unable to parse color from object: " + JSON.stringify(object));
        }
        this.model = hashedModelKeys[hashedKeys];
        const { labels } = convert[this.model];
        const color = [];
        for (i = 0; i < labels.length; i++) {
          color.push(object[labels[i]]);
        }
        this.color = zeroArray(color);
      }
      if (limiters[this.model]) {
        channels = convert[this.model].channels;
        for (i = 0; i < channels; i++) {
          const limit = limiters[this.model][i];
          if (limit) {
            this.color[i] = limit(this.color[i]);
          }
        }
      }
      this.valpha = Math.max(0, Math.min(1, this.valpha));
      if (Object.freeze) {
        Object.freeze(this);
      }
    }
    Color.prototype = {
      toString() {
        return this.string();
      },
      toJSON() {
        return this[this.model]();
      },
      string(places) {
        let self2 = this.model in cs.to ? this : this.rgb();
        self2 = self2.round(typeof places === "number" ? places : 1);
        const arguments_ = self2.valpha === 1 ? self2.color : [...self2.color, this.valpha];
        return cs.to[self2.model](...arguments_);
      },
      percentString(places) {
        const self2 = this.rgb().round(typeof places === "number" ? places : 1);
        const arguments_ = self2.valpha === 1 ? self2.color : [...self2.color, this.valpha];
        return cs.to.rgb.percent(...arguments_);
      },
      array() {
        return this.valpha === 1 ? [...this.color] : [...this.color, this.valpha];
      },
      object() {
        const result = {};
        const { channels } = convert[this.model];
        const { labels } = convert[this.model];
        for (let i = 0; i < channels; i++) {
          result[labels[i]] = this.color[i];
        }
        if (this.valpha !== 1) {
          result.alpha = this.valpha;
        }
        return result;
      },
      unitArray() {
        const rgb = this.rgb().color;
        rgb[0] /= 255;
        rgb[1] /= 255;
        rgb[2] /= 255;
        if (this.valpha !== 1) {
          rgb.push(this.valpha);
        }
        return rgb;
      },
      unitObject() {
        const rgb = this.rgb().object();
        rgb.r /= 255;
        rgb.g /= 255;
        rgb.b /= 255;
        if (this.valpha !== 1) {
          rgb.alpha = this.valpha;
        }
        return rgb;
      },
      round(places) {
        places = Math.max(places || 0, 0);
        return new Color([...this.color.map(roundToPlace(places)), this.valpha], this.model);
      },
      alpha(value) {
        if (value !== void 0) {
          return new Color([...this.color, Math.max(0, Math.min(1, value))], this.model);
        }
        return this.valpha;
      },
      // Rgb
      red: getset("rgb", 0, maxfn(255)),
      green: getset("rgb", 1, maxfn(255)),
      blue: getset("rgb", 2, maxfn(255)),
      hue: getset(["hsl", "hsv", "hsl", "hwb", "hcg"], 0, (value) => (value % 360 + 360) % 360),
      saturationl: getset("hsl", 1, maxfn(100)),
      lightness: getset("hsl", 2, maxfn(100)),
      saturationv: getset("hsv", 1, maxfn(100)),
      value: getset("hsv", 2, maxfn(100)),
      chroma: getset("hcg", 1, maxfn(100)),
      gray: getset("hcg", 2, maxfn(100)),
      white: getset("hwb", 1, maxfn(100)),
      wblack: getset("hwb", 2, maxfn(100)),
      cyan: getset("cmyk", 0, maxfn(100)),
      magenta: getset("cmyk", 1, maxfn(100)),
      yellow: getset("cmyk", 2, maxfn(100)),
      black: getset("cmyk", 3, maxfn(100)),
      x: getset("xyz", 0, maxfn(95.047)),
      y: getset("xyz", 1, maxfn(100)),
      z: getset("xyz", 2, maxfn(108.833)),
      l: getset("lab", 0, maxfn(100)),
      a: getset("lab", 1),
      b: getset("lab", 2),
      keyword(value) {
        if (value !== void 0) {
          return new Color(value);
        }
        return convert[this.model].keyword(this.color);
      },
      hex(value) {
        if (value !== void 0) {
          return new Color(value);
        }
        return cs.to.hex(...this.rgb().round().color);
      },
      hexa(value) {
        if (value !== void 0) {
          return new Color(value);
        }
        const rgbArray = this.rgb().round().color;
        let alphaHex = Math.round(this.valpha * 255).toString(16).toUpperCase();
        if (alphaHex.length === 1) {
          alphaHex = "0" + alphaHex;
        }
        return cs.to.hex(...rgbArray) + alphaHex;
      },
      rgbNumber() {
        const rgb = this.rgb().color;
        return (rgb[0] & 255) << 16 | (rgb[1] & 255) << 8 | rgb[2] & 255;
      },
      luminosity() {
        const rgb = this.rgb().color;
        const lum = [];
        for (const [i, element] of rgb.entries()) {
          const chan = element / 255;
          lum[i] = chan <= 0.04045 ? chan / 12.92 : ((chan + 0.055) / 1.055) ** 2.4;
        }
        return 0.2126 * lum[0] + 0.7152 * lum[1] + 0.0722 * lum[2];
      },
      contrast(color2) {
        const lum1 = this.luminosity();
        const lum2 = color2.luminosity();
        if (lum1 > lum2) {
          return (lum1 + 0.05) / (lum2 + 0.05);
        }
        return (lum2 + 0.05) / (lum1 + 0.05);
      },
      level(color2) {
        const contrastRatio = this.contrast(color2);
        if (contrastRatio >= 7) {
          return "AAA";
        }
        return contrastRatio >= 4.5 ? "AA" : "";
      },
      isDark() {
        const rgb = this.rgb().color;
        const yiq = (rgb[0] * 2126 + rgb[1] * 7152 + rgb[2] * 722) / 1e4;
        return yiq < 128;
      },
      isLight() {
        return !this.isDark();
      },
      negate() {
        const rgb = this.rgb();
        for (let i = 0; i < 3; i++) {
          rgb.color[i] = 255 - rgb.color[i];
        }
        return rgb;
      },
      lighten(ratio) {
        const hsl = this.hsl();
        hsl.color[2] += hsl.color[2] * ratio;
        return hsl;
      },
      darken(ratio) {
        const hsl = this.hsl();
        hsl.color[2] -= hsl.color[2] * ratio;
        return hsl;
      },
      saturate(ratio) {
        const hsl = this.hsl();
        hsl.color[1] += hsl.color[1] * ratio;
        return hsl;
      },
      desaturate(ratio) {
        const hsl = this.hsl();
        hsl.color[1] -= hsl.color[1] * ratio;
        return hsl;
      },
      whiten(ratio) {
        const hwb = this.hwb();
        hwb.color[1] += hwb.color[1] * ratio;
        return hwb;
      },
      blacken(ratio) {
        const hwb = this.hwb();
        hwb.color[2] += hwb.color[2] * ratio;
        return hwb;
      },
      grayscale() {
        const rgb = this.rgb().color;
        const value = rgb[0] * 0.3 + rgb[1] * 0.59 + rgb[2] * 0.11;
        return Color.rgb(value, value, value);
      },
      fade(ratio) {
        return this.alpha(this.valpha - this.valpha * ratio);
      },
      opaquer(ratio) {
        return this.alpha(this.valpha + this.valpha * ratio);
      },
      rotate(degrees) {
        const hsl = this.hsl();
        let hue = hsl.color[0];
        hue = (hue + degrees) % 360;
        hue = hue < 0 ? 360 + hue : hue;
        hsl.color[0] = hue;
        return hsl;
      },
      mix(mixinColor, weight) {
        if (!mixinColor || !mixinColor.rgb) {
          throw new Error('Argument to "mix" was not a Color instance, but rather an instance of ' + typeof mixinColor);
        }
        const color1 = mixinColor.rgb();
        const color2 = this.rgb();
        const p = weight === void 0 ? 0.5 : weight;
        const w = 2 * p - 1;
        const a = color1.alpha() - color2.alpha();
        const w1 = ((w * a === -1 ? w : (w + a) / (1 + w * a)) + 1) / 2;
        const w2 = 1 - w1;
        return Color.rgb(
          w1 * color1.red() + w2 * color2.red(),
          w1 * color1.green() + w2 * color2.green(),
          w1 * color1.blue() + w2 * color2.blue(),
          color1.alpha() * p + color2.alpha() * (1 - p)
        );
      }
    };
    for (const model of Object.keys(convert)) {
      if (skippedModels.includes(model)) {
        continue;
      }
      const { channels } = convert[model];
      Color.prototype[model] = function(...arguments_) {
        if (this.model === model) {
          return new Color(this);
        }
        if (arguments_.length > 0) {
          return new Color(arguments_, model);
        }
        return new Color([...assertArray(convert[this.model][model].raw(this.color)), this.valpha], model);
      };
      Color[model] = function(...arguments_) {
        let color = arguments_[0];
        if (typeof color === "number") {
          color = zeroArray(arguments_, channels);
        }
        return new Color(color, model);
      };
    }
    function roundTo(number, places) {
      return Number(number.toFixed(places));
    }
    function roundToPlace(places) {
      return function(number) {
        return roundTo(number, places);
      };
    }
    function getset(model, channel, modifier) {
      model = Array.isArray(model) ? model : [model];
      for (const m of model) {
        (limiters[m] ||= [])[channel] = modifier;
      }
      model = model[0];
      return function(value) {
        let result;
        if (value !== void 0) {
          if (modifier) {
            value = modifier(value);
          }
          result = this[model]();
          result.color[channel] = value;
          return result;
        }
        result = this[model]().color[channel];
        if (modifier) {
          result = modifier(result);
        }
        return result;
      };
    }
    function maxfn(max) {
      return function(v) {
        return Math.max(0, Math.min(max, v));
      };
    }
    function assertArray(value) {
      return Array.isArray(value) ? value : [value];
    }
    function zeroArray(array, length) {
      for (let i = 0; i < length; i++) {
        if (typeof array[i] !== "number") {
          array[i] = 0;
        }
      }
      return array;
    }
    function getDefaultExportFromCjs(x) {
      return x && x.__esModule && Object.prototype.hasOwnProperty.call(x, "default") ? x["default"] : x;
    }
    var textHex = function hex2(str) {
      for (var i = 0, hash = 0; i < str.length; hash = str.charCodeAt(i++) + ((hash << 5) - hash)) ;
      var color = Math.floor(
        Math.abs(
          Math.sin(hash) * 1e4 % 1 * 16777216
        )
      ).toString(16);
      return "#" + Array(6 - color.length + 1).join("0") + color;
    };
    var hex = /* @__PURE__ */ getDefaultExportFromCjs(textHex);
    function colorspace(namespace, delimiter) {
      const split = namespace.split(delimiter || ":");
      let base = hex(split[0]);
      if (!split.length) return base;
      for (let i = 0, l = split.length - 1; i < l; i++) {
        base = Color(base).mix(Color(hex(split[i + 1]))).saturate(1).hex();
      }
      return base;
    }
    module2.exports = colorspace;
  }
});

// node_modules/kuler/index.js
var require_kuler = __commonJS({
  "node_modules/kuler/index.js"(exports2, module2) {
    "use strict";
    function Kuler(text, color) {
      if (color) return new Kuler(text).style(color);
      if (!(this instanceof Kuler)) return new Kuler(text);
      this.text = text;
    }
    Kuler.prototype.prefix = "\x1B[";
    Kuler.prototype.suffix = "m";
    Kuler.prototype.hex = function hex(color) {
      color = color[0] === "#" ? color.substring(1) : color;
      if (color.length === 3) {
        color = color.split("");
        color[5] = color[2];
        color[4] = color[2];
        color[3] = color[1];
        color[2] = color[1];
        color[1] = color[0];
        color = color.join("");
      }
      var r = color.substring(0, 2), g = color.substring(2, 4), b = color.substring(4, 6);
      return [parseInt(r, 16), parseInt(g, 16), parseInt(b, 16)];
    };
    Kuler.prototype.rgb = function rgb(r, g, b) {
      var red = r / 255 * 5, green = g / 255 * 5, blue = b / 255 * 5;
      return this.ansi(red, green, blue);
    };
    Kuler.prototype.ansi = function ansi(r, g, b) {
      var red = Math.round(r), green = Math.round(g), blue = Math.round(b);
      return 16 + red * 36 + green * 6 + blue;
    };
    Kuler.prototype.reset = function reset() {
      return this.prefix + "39;49" + this.suffix;
    };
    Kuler.prototype.style = function style(color) {
      return this.prefix + "38;5;" + this.rgb.apply(this, this.hex(color)) + this.suffix + this.text + this.reset();
    };
    module2.exports = Kuler;
  }
});

// node_modules/@dabh/diagnostics/modifiers/namespace-ansi.js
var require_namespace_ansi = __commonJS({
  "node_modules/@dabh/diagnostics/modifiers/namespace-ansi.js"(exports2, module2) {
    var colorspace = require_index_cjs();
    var kuler = require_kuler();
    module2.exports = function ansiModifier(args, options) {
      var namespace = options.namespace;
      var ansi = options.colors !== false ? kuler(namespace + ":", colorspace(namespace)) : namespace + ":";
      args[0] = ansi + " " + args[0];
      return args;
    };
  }
});

// node_modules/enabled/index.js
var require_enabled = __commonJS({
  "node_modules/enabled/index.js"(exports2, module2) {
    "use strict";
    module2.exports = function enabled(name, variable) {
      if (!variable) return false;
      var variables = variable.split(/[\s,]+/), i = 0;
      for (; i < variables.length; i++) {
        variable = variables[i].replace("*", ".*?");
        if ("-" === variable.charAt(0)) {
          if (new RegExp("^" + variable.substr(1) + "$").test(name)) {
            return false;
          }
          continue;
        }
        if (new RegExp("^" + variable + "$").test(name)) {
          return true;
        }
      }
      return false;
    };
  }
});

// node_modules/@dabh/diagnostics/adapters/index.js
var require_adapters = __commonJS({
  "node_modules/@dabh/diagnostics/adapters/index.js"(exports2, module2) {
    var enabled = require_enabled();
    module2.exports = function create(fn) {
      return function adapter(namespace) {
        try {
          return enabled(namespace, fn());
        } catch (e) {
        }
        return false;
      };
    };
  }
});

// node_modules/@dabh/diagnostics/adapters/process.env.js
var require_process_env = __commonJS({
  "node_modules/@dabh/diagnostics/adapters/process.env.js"(exports2, module2) {
    var adapter = require_adapters();
    module2.exports = adapter(function processenv() {
      return process.env.DEBUG || process.env.DIAGNOSTICS;
    });
  }
});

// node_modules/@dabh/diagnostics/logger/console.js
var require_console2 = __commonJS({
  "node_modules/@dabh/diagnostics/logger/console.js"(exports2, module2) {
    module2.exports = function(meta, messages) {
      try {
        Function.prototype.apply.call(console.log, console, messages);
      } catch (e) {
      }
    };
  }
});

// node_modules/@dabh/diagnostics/node/development.js
var require_development = __commonJS({
  "node_modules/@dabh/diagnostics/node/development.js"(exports2, module2) {
    var create = require_diagnostics();
    var tty = require("tty").isatty(1);
    var diagnostics = create(function dev(namespace, options) {
      options = options || {};
      options.colors = "colors" in options ? options.colors : tty;
      options.namespace = namespace;
      options.prod = false;
      options.dev = true;
      if (!dev.enabled(namespace) && !(options.force || dev.force)) {
        return dev.nope(options);
      }
      return dev.yep(options);
    });
    diagnostics.modify(require_namespace_ansi());
    diagnostics.use(require_process_env());
    diagnostics.set(require_console2());
    module2.exports = diagnostics;
  }
});

// node_modules/@dabh/diagnostics/node/index.js
var require_node2 = __commonJS({
  "node_modules/@dabh/diagnostics/node/index.js"(exports2, module2) {
    if (process.env.NODE_ENV === "production") {
      module2.exports = require_production();
    } else {
      module2.exports = require_development();
    }
  }
});

// node_modules/winston/lib/winston/tail-file.js
var require_tail_file = __commonJS({
  "node_modules/winston/lib/winston/tail-file.js"(exports2, module2) {
    "use strict";
    var fs2 = require("fs");
    var { StringDecoder } = require("string_decoder");
    var { Stream } = require_readable();
    function noop() {
    }
    module2.exports = (options, iter) => {
      const buffer = Buffer.alloc(64 * 1024);
      const decode = new StringDecoder("utf8");
      const stream = new Stream();
      let buff = "";
      let pos = 0;
      let row2 = 0;
      if (options.start === -1) {
        delete options.start;
      }
      stream.readable = true;
      stream.destroy = () => {
        stream.destroyed = true;
        stream.emit("end");
        stream.emit("close");
      };
      fs2.open(options.file, "a+", "0644", (err, fd) => {
        if (err) {
          if (!iter) {
            stream.emit("error", err);
          } else {
            iter(err);
          }
          stream.destroy();
          return;
        }
        (function read() {
          if (stream.destroyed) {
            fs2.close(fd, noop);
            return;
          }
          return fs2.read(fd, buffer, 0, buffer.length, pos, (error, bytes) => {
            if (error) {
              if (!iter) {
                stream.emit("error", error);
              } else {
                iter(error);
              }
              stream.destroy();
              return;
            }
            if (!bytes) {
              if (buff) {
                if (options.start == null || row2 > options.start) {
                  if (!iter) {
                    stream.emit("line", buff);
                  } else {
                    iter(null, buff);
                  }
                }
                row2++;
                buff = "";
              }
              return setTimeout(read, 1e3);
            }
            let data = decode.write(buffer.slice(0, bytes));
            if (!iter) {
              stream.emit("data", data);
            }
            data = (buff + data).split(/\n+/);
            const l = data.length - 1;
            let i = 0;
            for (; i < l; i++) {
              if (options.start == null || row2 > options.start) {
                if (!iter) {
                  stream.emit("line", data[i]);
                } else {
                  iter(null, data[i]);
                }
              }
              row2++;
            }
            buff = data[l];
            pos += bytes;
            return read();
          });
        })();
      });
      if (!iter) {
        return stream;
      }
      return stream.destroy;
    };
  }
});

// node_modules/winston/lib/winston/transports/file.js
var require_file = __commonJS({
  "node_modules/winston/lib/winston/transports/file.js"(exports2, module2) {
    "use strict";
    var fs2 = require("fs");
    var path2 = require("path");
    var asyncSeries = require_series();
    var zlib = require("zlib");
    var { MESSAGE } = require_triple_beam();
    var { Stream, PassThrough } = require_readable();
    var TransportStream = require_winston_transport();
    var debug = require_node2()("winston:file");
    var os2 = require("os");
    var tailFile = require_tail_file();
    module2.exports = class File extends TransportStream {
      /**
       * Constructor function for the File transport object responsible for
       * persisting log messages and metadata to one or more files.
       * @param {Object} options - Options for this instance.
       */
      constructor(options = {}) {
        super(options);
        this.name = options.name || "file";
        function throwIf(target, ...args) {
          args.slice(1).forEach((name) => {
            if (options[name]) {
              throw new Error(`Cannot set ${name} and ${target} together`);
            }
          });
        }
        this._stream = new PassThrough();
        this._stream.setMaxListeners(30);
        this._onError = this._onError.bind(this);
        if (options.filename || options.dirname) {
          throwIf("filename or dirname", "stream");
          this._basename = this.filename = options.filename ? path2.basename(options.filename) : "winston.log";
          this.dirname = options.dirname || path2.dirname(options.filename);
          this.options = options.options || { flags: "a" };
        } else if (options.stream) {
          console.warn("options.stream will be removed in winston@4. Use winston.transports.Stream");
          throwIf("stream", "filename", "maxsize");
          this._dest = this._stream.pipe(this._setupStream(options.stream));
          this.dirname = path2.dirname(this._dest.path);
        } else {
          throw new Error("Cannot log to file without filename or stream.");
        }
        this.maxsize = options.maxsize || null;
        this.rotationFormat = options.rotationFormat || false;
        this.zippedArchive = options.zippedArchive || false;
        this.maxFiles = options.maxFiles || null;
        this.eol = typeof options.eol === "string" ? options.eol : os2.EOL;
        this.tailable = options.tailable || false;
        this.lazy = options.lazy || false;
        this._size = 0;
        this._pendingSize = 0;
        this._created = 0;
        this._drain = false;
        this._opening = false;
        this._ending = false;
        this._fileExist = false;
        if (this.dirname) this._createLogDirIfNotExist(this.dirname);
        if (!this.lazy) this.open();
      }
      finishIfEnding() {
        if (this._ending) {
          if (this._opening) {
            this.once("open", () => {
              this._stream.once("finish", () => this.emit("finish"));
              setImmediate(() => this._stream.end());
            });
          } else {
            this._stream.once("finish", () => this.emit("finish"));
            setImmediate(() => this._stream.end());
          }
        }
      }
      /**
       * Called by Node.js Writable stream before emitting 'finish'.
       * Ensures all buffered data is flushed to the underlying file stream
       * before the transport signals completion.
       * @param {Function} callback - Callback to signal completion.
       * @private
       */
      _final(callback) {
        if (this._opening) {
          this.once("open", () => this._final(callback));
          return;
        }
        this._stream.end();
        if (!this._dest) {
          return callback();
        }
        if (this._dest.writableFinished) {
          return callback();
        }
        this._dest.once("finish", callback);
        this._dest.once("error", callback);
      }
      /**
       * Core logging method exposed to Winston. Metadata is optional.
       * @param {Object} info - TODO: add param description.
       * @param {Function} callback - TODO: add param description.
       * @returns {undefined}
       */
      log(info, callback = () => {
      }) {
        if (this.silent) {
          callback();
          return true;
        }
        if (this._drain) {
          this._stream.once("drain", () => {
            this._drain = false;
            this.log(info, callback);
          });
          return;
        }
        if (this._rotate) {
          this._stream.once("rotate", () => {
            this._rotate = false;
            this.log(info, callback);
          });
          return;
        }
        if (this.lazy) {
          if (!this._fileExist) {
            if (!this._opening) {
              this.open();
            }
            this.once("open", () => {
              this._fileExist = true;
              this.log(info, callback);
              return;
            });
            return;
          }
          if (this._needsNewFile(this._pendingSize)) {
            this._dest.once("close", () => {
              if (!this._opening) {
                this.open();
              }
              this.once("open", () => {
                this.log(info, callback);
                return;
              });
              return;
            });
            return;
          }
        }
        const output = `${info[MESSAGE]}${this.eol}`;
        const bytes = Buffer.byteLength(output);
        function logged() {
          this._size += bytes;
          this._pendingSize -= bytes;
          debug("logged %s %s", this._size, output);
          this.emit("logged", info);
          if (this._rotate) {
            return;
          }
          if (this._opening) {
            return;
          }
          if (!this._needsNewFile()) {
            return;
          }
          if (this.lazy) {
            this._endStream(() => {
              this.emit("fileclosed");
            });
            return;
          }
          this._rotate = true;
          this._endStream(() => this._rotateFile());
        }
        this._pendingSize += bytes;
        if (this._opening && !this.rotatedWhileOpening && this._needsNewFile(this._size + this._pendingSize)) {
          this.rotatedWhileOpening = true;
        }
        const written = this._stream.write(output, logged.bind(this));
        if (!written) {
          this._drain = true;
          this._stream.once("drain", () => {
            this._drain = false;
            callback();
          });
        } else {
          callback();
        }
        debug("written", written, this._drain);
        this.finishIfEnding();
        return written;
      }
      /**
       * Query the transport. Options object is optional.
       * @param {Object} options - Loggly-like query options for this instance.
       * @param {function} callback - Continuation to respond to when complete.
       * TODO: Refactor me.
       */
      query(options, callback) {
        if (typeof options === "function") {
          callback = options;
          options = {};
        }
        options = normalizeQuery(options);
        const file = path2.join(this.dirname, this.filename);
        let buff = "";
        let results = [];
        let row2 = 0;
        const stream = fs2.createReadStream(file, {
          encoding: "utf8"
        });
        stream.on("error", (err) => {
          if (stream.readable) {
            stream.destroy();
          }
          if (!callback) {
            return;
          }
          return err.code !== "ENOENT" ? callback(err) : callback(null, results);
        });
        stream.on("data", (data) => {
          data = (buff + data).split(/\n+/);
          const l = data.length - 1;
          let i = 0;
          for (; i < l; i++) {
            if (!options.start || row2 >= options.start) {
              add(data[i]);
            }
            row2++;
          }
          buff = data[l];
        });
        stream.on("close", () => {
          if (buff) {
            add(buff, true);
          }
          if (options.order === "desc") {
            results = results.reverse();
          }
          if (callback) callback(null, results);
        });
        function add(buff2, attempt) {
          try {
            const log = JSON.parse(buff2);
            if (check(log)) {
              push(log);
            }
          } catch (e) {
            if (!attempt) {
              stream.emit("error", e);
            }
          }
        }
        function push(log) {
          if (options.rows && results.length >= options.rows && options.order !== "desc") {
            if (stream.readable) {
              stream.destroy();
            }
            return;
          }
          if (options.fields) {
            log = options.fields.reduce((obj, key) => {
              obj[key] = log[key];
              return obj;
            }, {});
          }
          if (options.order === "desc") {
            if (results.length >= options.rows) {
              results.shift();
            }
          }
          results.push(log);
        }
        function check(log) {
          if (!log) {
            return;
          }
          if (typeof log !== "object") {
            return;
          }
          const time = new Date(log.timestamp);
          if (options.from && time < options.from || options.until && time > options.until || options.level && options.level !== log.level) {
            return;
          }
          return true;
        }
        function normalizeQuery(options2) {
          options2 = options2 || {};
          options2.rows = options2.rows || options2.limit || 10;
          options2.start = options2.start || 0;
          options2.until = options2.until || /* @__PURE__ */ new Date();
          if (typeof options2.until !== "object") {
            options2.until = new Date(options2.until);
          }
          options2.from = options2.from || options2.until - 24 * 60 * 60 * 1e3;
          if (typeof options2.from !== "object") {
            options2.from = new Date(options2.from);
          }
          options2.order = options2.order || "desc";
          return options2;
        }
      }
      /**
       * Returns a log stream for this transport. Options object is optional.
       * @param {Object} options - Stream options for this instance.
       * @returns {Stream} - TODO: add return description.
       * TODO: Refactor me.
       */
      stream(options = {}) {
        const file = path2.join(this.dirname, this.filename);
        const stream = new Stream();
        const tail = {
          file,
          start: options.start
        };
        stream.destroy = tailFile(tail, (err, line) => {
          if (err) {
            return stream.emit("error", err);
          }
          try {
            stream.emit("data", line);
            line = JSON.parse(line);
            stream.emit("log", line);
          } catch (e) {
            stream.emit("error", e);
          }
        });
        return stream;
      }
      /**
       * Checks to see the filesize of.
       * @returns {undefined}
       */
      open() {
        if (!this.filename) return;
        if (this._opening) return;
        this._opening = true;
        this.stat((err, size) => {
          if (err) {
            return this.emit("error", err);
          }
          debug("stat done: %s { size: %s }", this.filename, size);
          this._size = size;
          this._dest = this._createStream(this._stream);
          this._opening = false;
          this.once("open", () => {
            if (!this._stream.emit("rotate")) {
              this._rotate = false;
            }
          });
        });
      }
      /**
       * Stat the file and assess information in order to create the proper stream.
       * @param {function} callback - TODO: add param description.
       * @returns {undefined}
       */
      stat(callback) {
        const target = this._getFile();
        const fullpath = path2.join(this.dirname, target);
        fs2.stat(fullpath, (err, stat) => {
          if (err && err.code === "ENOENT") {
            debug("ENOENT\xA0ok", fullpath);
            this.filename = target;
            return callback(null, 0);
          }
          if (err) {
            debug(`err ${err.code} ${fullpath}`);
            return callback(err);
          }
          if (!stat || this._needsNewFile(stat.size)) {
            return this._incFile(() => this.stat(callback));
          }
          this.filename = target;
          callback(null, stat.size);
        });
      }
      /**
       * Closes the stream associated with this instance.
       * @param {function} cb - TODO: add param description.
       * @returns {undefined}
       */
      close(cb) {
        if (!this._stream) {
          return;
        }
        this._stream.end(() => {
          if (cb) {
            cb();
          }
          this.emit("flush");
          this.emit("closed");
        });
      }
      /**
       * TODO: add method description.
       * @param {number} size - TODO: add param description.
       * @returns {undefined}
       */
      _needsNewFile(size) {
        size = size || this._size;
        return this.maxsize && size >= this.maxsize;
      }
      /**
       * TODO: add method description.
       * @param {Error} err - TODO: add param description.
       * @returns {undefined}
       */
      _onError(err) {
        this.emit("error", err);
      }
      /**
       * TODO: add method description.
       * @param {Stream} stream - TODO: add param description.
       * @returns {mixed} - TODO: add return description.
       */
      _setupStream(stream) {
        stream.on("error", this._onError);
        return stream;
      }
      /**
       * TODO: add method description.
       * @param {Stream} stream - TODO: add param description.
       * @returns {mixed} - TODO: add return description.
       */
      _cleanupStream(stream) {
        stream.removeListener("error", this._onError);
        stream.destroy();
        return stream;
      }
      /**
       * TODO: add method description.
       */
      _rotateFile() {
        this._incFile(() => this.open());
      }
      /**
       * Unpipe from the stream that has been marked as full and end it so it
       * flushes to disk.
       *
       * @param {function} callback - Callback for when the current file has closed.
       * @private
       */
      _endStream(callback = () => {
      }) {
        if (this._dest) {
          this._stream.unpipe(this._dest);
          this._dest.end(() => {
            this._cleanupStream(this._dest);
            callback();
          });
        } else {
          callback();
        }
      }
      /**
       * Returns the WritableStream for the active file on this instance. If we
       * should gzip the file then a zlib stream is returned.
       *
       * @param {ReadableStream} source –PassThrough to pipe to the file when open.
       * @returns {WritableStream} Stream that writes to disk for the active file.
       */
      _createStream(source) {
        const fullpath = path2.join(this.dirname, this.filename);
        debug("create stream start", fullpath, this.options);
        const dest = fs2.createWriteStream(fullpath, this.options).on("error", (err) => debug(err)).on("close", () => debug("close", dest.path, dest.bytesWritten)).on("open", () => {
          debug("file open ok", fullpath);
          this.emit("open", fullpath);
          source.pipe(dest);
          if (this.rotatedWhileOpening) {
            this._stream = new PassThrough();
            this._stream.setMaxListeners(30);
            this._rotateFile();
            this.rotatedWhileOpening = false;
            this._cleanupStream(dest);
            source.end();
          }
        });
        debug("create stream ok", fullpath);
        return dest;
      }
      /**
       * TODO: add method description.
       * @param {function} callback - TODO: add param description.
       * @returns {undefined}
       */
      _incFile(callback) {
        debug("_incFile", this.filename);
        const ext = path2.extname(this._basename);
        const basename = path2.basename(this._basename, ext);
        const tasks = [];
        if (this.zippedArchive) {
          tasks.push(
            function(cb) {
              const num = this._created > 0 && !this.tailable ? this._created : "";
              this._compressFile(
                path2.join(this.dirname, `${basename}${num}${ext}`),
                path2.join(this.dirname, `${basename}${num}${ext}.gz`),
                cb
              );
            }.bind(this)
          );
        }
        tasks.push(
          function(cb) {
            if (!this.tailable) {
              this._created += 1;
              this._checkMaxFilesIncrementing(ext, basename, cb);
            } else {
              this._checkMaxFilesTailable(ext, basename, cb);
            }
          }.bind(this)
        );
        asyncSeries(tasks, callback);
      }
      /**
       * Gets the next filename to use for this instance in the case that log
       * filesizes are being capped.
       * @returns {string} - TODO: add return description.
       * @private
       */
      _getFile() {
        const ext = path2.extname(this._basename);
        const basename = path2.basename(this._basename, ext);
        const isRotation = this.rotationFormat ? this.rotationFormat() : this._created;
        return !this.tailable && this._created ? `${basename}${isRotation}${ext}` : `${basename}${ext}`;
      }
      /**
       * Increment the number of files created or checked by this instance.
       * @param {mixed} ext - TODO: add param description.
       * @param {mixed} basename - TODO: add param description.
       * @param {mixed} callback - TODO: add param description.
       * @returns {undefined}
       * @private
       */
      _checkMaxFilesIncrementing(ext, basename, callback) {
        if (!this.maxFiles || this._created < this.maxFiles) {
          return setImmediate(callback);
        }
        const oldest = this._created - this.maxFiles;
        const isOldest = oldest !== 0 ? oldest : "";
        const isZipped = this.zippedArchive ? ".gz" : "";
        const filePath = `${basename}${isOldest}${ext}${isZipped}`;
        const target = path2.join(this.dirname, filePath);
        fs2.unlink(target, callback);
      }
      /**
       * Roll files forward based on integer, up to maxFiles. e.g. if base if
       * file.log and it becomes oversized, roll to file1.log, and allow file.log
       * to be re-used. If file is oversized again, roll file1.log to file2.log,
       * roll file.log to file1.log, and so on.
       * @param {mixed} ext - TODO: add param description.
       * @param {mixed} basename - TODO: add param description.
       * @param {mixed} callback - TODO: add param description.
       * @returns {undefined}
       * @private
       */
      _checkMaxFilesTailable(ext, basename, callback) {
        const tasks = [];
        if (!this.maxFiles) {
          return;
        }
        const isZipped = this.zippedArchive ? ".gz" : "";
        for (let x = this.maxFiles - 1; x > 1; x--) {
          tasks.push(function(i, cb) {
            let fileName = `${basename}${i - 1}${ext}${isZipped}`;
            const tmppath = path2.join(this.dirname, fileName);
            fs2.exists(tmppath, (exists) => {
              if (!exists) {
                return cb(null);
              }
              fileName = `${basename}${i}${ext}${isZipped}`;
              fs2.rename(tmppath, path2.join(this.dirname, fileName), cb);
            });
          }.bind(this, x));
        }
        asyncSeries(tasks, () => {
          fs2.rename(
            path2.join(this.dirname, `${basename}${ext}${isZipped}`),
            path2.join(this.dirname, `${basename}1${ext}${isZipped}`),
            callback
          );
        });
      }
      /**
       * Compresses src to dest with gzip and unlinks src
       * @param {string} src - path to source file.
       * @param {string} dest - path to zipped destination file.
       * @param {Function} callback - callback called after file has been compressed.
       * @returns {undefined}
       * @private
       */
      _compressFile(src, dest, callback) {
        fs2.access(src, fs2.F_OK, (err) => {
          if (err) {
            return callback();
          }
          var gzip = zlib.createGzip();
          var inp = fs2.createReadStream(src);
          var out = fs2.createWriteStream(dest);
          out.on("finish", () => {
            fs2.unlink(src, callback);
          });
          inp.pipe(gzip).pipe(out);
        });
      }
      _createLogDirIfNotExist(dirPath) {
        if (!fs2.existsSync(dirPath)) {
          fs2.mkdirSync(dirPath, { recursive: true });
        }
      }
    };
  }
});

// node_modules/winston/lib/winston/transports/http.js
var require_http = __commonJS({
  "node_modules/winston/lib/winston/transports/http.js"(exports2, module2) {
    "use strict";
    var http = require("http");
    var https = require("https");
    var { Stream } = require_readable();
    var TransportStream = require_winston_transport();
    var { configure } = require_safe_stable_stringify();
    module2.exports = class Http extends TransportStream {
      /**
       * Constructor function for the Http transport object responsible for
       * persisting log messages and metadata to a terminal or TTY.
       * @param {!Object} [options={}] - Options for this instance.
       */
      // eslint-disable-next-line max-statements
      constructor(options = {}) {
        super(options);
        this.options = options;
        this.name = options.name || "http";
        this.ssl = !!options.ssl;
        this.host = options.host || "localhost";
        this.port = options.port;
        this.auth = options.auth;
        this.path = options.path || "";
        this.maximumDepth = options.maximumDepth;
        this.agent = options.agent;
        this.headers = options.headers || {};
        this.headers["content-type"] = "application/json";
        this.batch = options.batch || false;
        this.batchInterval = options.batchInterval || 5e3;
        this.batchCount = options.batchCount || 10;
        this.batchOptions = [];
        this.batchTimeoutID = -1;
        this.batchCallback = {};
        if (!this.port) {
          this.port = this.ssl ? 443 : 80;
        }
      }
      /**
       * Core logging method exposed to Winston.
       * @param {Object} info - TODO: add param description.
       * @param {function} callback - TODO: add param description.
       * @returns {undefined}
       */
      log(info, callback) {
        this._request(info, null, null, (err, res) => {
          if (res && res.statusCode !== 200) {
            err = new Error(`Invalid HTTP Status Code: ${res.statusCode}`);
          }
          if (err) {
            this.emit("warn", err);
          } else {
            this.emit("logged", info);
          }
        });
        if (callback) {
          setImmediate(callback);
        }
      }
      /**
       * Query the transport. Options object is optional.
       * @param {Object} options -  Loggly-like query options for this instance.
       * @param {function} callback - Continuation to respond to when complete.
       * @returns {undefined}
       */
      query(options, callback) {
        if (typeof options === "function") {
          callback = options;
          options = {};
        }
        options = {
          method: "query",
          params: this.normalizeQuery(options)
        };
        const auth = options.params.auth || null;
        delete options.params.auth;
        const path2 = options.params.path || null;
        delete options.params.path;
        this._request(options, auth, path2, (err, res, body) => {
          if (res && res.statusCode !== 200) {
            err = new Error(`Invalid HTTP Status Code: ${res.statusCode}`);
          }
          if (err) {
            return callback(err);
          }
          if (typeof body === "string") {
            try {
              body = JSON.parse(body);
            } catch (e) {
              return callback(e);
            }
          }
          callback(null, body);
        });
      }
      /**
       * Returns a log stream for this transport. Options object is optional.
       * @param {Object} options - Stream options for this instance.
       * @returns {Stream} - TODO: add return description
       */
      stream(options = {}) {
        const stream = new Stream();
        options = {
          method: "stream",
          params: options
        };
        const path2 = options.params.path || null;
        delete options.params.path;
        const auth = options.params.auth || null;
        delete options.params.auth;
        let buff = "";
        const req = this._request(options, auth, path2);
        stream.destroy = () => req.destroy();
        req.on("data", (data) => {
          data = (buff + data).split(/\n+/);
          const l = data.length - 1;
          let i = 0;
          for (; i < l; i++) {
            try {
              stream.emit("log", JSON.parse(data[i]));
            } catch (e) {
              stream.emit("error", e);
            }
          }
          buff = data[l];
        });
        req.on("error", (err) => stream.emit("error", err));
        return stream;
      }
      /**
       * Make a request to a winstond server or any http server which can
       * handle json-rpc.
       * @param {function} options - Options to sent the request.
       * @param {Object?} auth - authentication options
       * @param {string} path - request path
       * @param {function} callback - Continuation to respond to when complete.
       */
      _request(options, auth, path2, callback) {
        options = options || {};
        auth = auth || this.auth;
        path2 = path2 || this.path || "";
        if (this.batch) {
          this._doBatch(options, callback, auth, path2);
        } else {
          this._doRequest(options, callback, auth, path2);
        }
      }
      /**
       * Send or memorize the options according to batch configuration
       * @param {function} options - Options to sent the request.
       * @param {function} callback - Continuation to respond to when complete.
       * @param {Object?} auth - authentication options
       * @param {string} path - request path
       */
      _doBatch(options, callback, auth, path2) {
        this.batchOptions.push(options);
        if (this.batchOptions.length === 1) {
          const me = this;
          this.batchCallback = callback;
          this.batchTimeoutID = setTimeout(function() {
            me.batchTimeoutID = -1;
            me._doBatchRequest(me.batchCallback, auth, path2);
          }, this.batchInterval);
        }
        if (this.batchOptions.length === this.batchCount) {
          this._doBatchRequest(this.batchCallback, auth, path2);
        }
      }
      /**
       * Initiate a request with the memorized batch options, stop the batch timeout
       * @param {function} callback - Continuation to respond to when complete.
       * @param {Object?} auth - authentication options
       * @param {string} path - request path
       */
      _doBatchRequest(callback, auth, path2) {
        if (this.batchTimeoutID > 0) {
          clearTimeout(this.batchTimeoutID);
          this.batchTimeoutID = -1;
        }
        const batchOptionsCopy = this.batchOptions.slice();
        this.batchOptions = [];
        this._doRequest(batchOptionsCopy, callback, auth, path2);
      }
      /**
       * Make a request to a winstond server or any http server which can
       * handle json-rpc.
       * @param {function} options - Options to sent the request.
       * @param {function} callback - Continuation to respond to when complete.
       * @param {Object?} auth - authentication options
       * @param {string} path - request path
       */
      _doRequest(options, callback, auth, path2) {
        const headers = Object.assign({}, this.headers);
        if (auth && auth.bearer) {
          headers.Authorization = `Bearer ${auth.bearer}`;
        }
        const req = (this.ssl ? https : http).request({
          ...this.options,
          method: "POST",
          host: this.host,
          port: this.port,
          path: `/${path2.replace(/^\//, "")}`,
          headers,
          auth: auth && auth.username && auth.password ? `${auth.username}:${auth.password}` : "",
          agent: this.agent
        });
        req.on("error", callback);
        req.on("response", (res) => res.on("end", () => callback(null, res)).resume());
        const jsonStringify = configure({
          ...this.maximumDepth && { maximumDepth: this.maximumDepth }
        });
        req.end(Buffer.from(jsonStringify(options, this.options.replacer), "utf8"));
      }
    };
  }
});

// node_modules/is-stream/index.js
var require_is_stream = __commonJS({
  "node_modules/is-stream/index.js"(exports2, module2) {
    "use strict";
    var isStream = (stream) => stream !== null && typeof stream === "object" && typeof stream.pipe === "function";
    isStream.writable = (stream) => isStream(stream) && stream.writable !== false && typeof stream._write === "function" && typeof stream._writableState === "object";
    isStream.readable = (stream) => isStream(stream) && stream.readable !== false && typeof stream._read === "function" && typeof stream._readableState === "object";
    isStream.duplex = (stream) => isStream.writable(stream) && isStream.readable(stream);
    isStream.transform = (stream) => isStream.duplex(stream) && typeof stream._transform === "function";
    module2.exports = isStream;
  }
});

// node_modules/winston/lib/winston/transports/stream.js
var require_stream2 = __commonJS({
  "node_modules/winston/lib/winston/transports/stream.js"(exports2, module2) {
    "use strict";
    var isStream = require_is_stream();
    var { MESSAGE } = require_triple_beam();
    var os2 = require("os");
    var TransportStream = require_winston_transport();
    module2.exports = class Stream extends TransportStream {
      /**
       * Constructor function for the Console transport object responsible for
       * persisting log messages and metadata to a terminal or TTY.
       * @param {!Object} [options={}] - Options for this instance.
       */
      constructor(options = {}) {
        super(options);
        if (!options.stream || !isStream(options.stream)) {
          throw new Error("options.stream is required.");
        }
        this._stream = options.stream;
        this._stream.setMaxListeners(Infinity);
        this.isObjectMode = options.stream._writableState.objectMode;
        this.eol = typeof options.eol === "string" ? options.eol : os2.EOL;
      }
      /**
       * Core logging method exposed to Winston.
       * @param {Object} info - TODO: add param description.
       * @param {Function} callback - TODO: add param description.
       * @returns {undefined}
       */
      log(info, callback) {
        setImmediate(() => this.emit("logged", info));
        if (this.isObjectMode) {
          this._stream.write(info);
          if (callback) {
            callback();
          }
          return;
        }
        this._stream.write(`${info[MESSAGE]}${this.eol}`);
        if (callback) {
          callback();
        }
        return;
      }
    };
  }
});

// node_modules/winston/lib/winston/transports/index.js
var require_transports = __commonJS({
  "node_modules/winston/lib/winston/transports/index.js"(exports2) {
    "use strict";
    Object.defineProperty(exports2, "Console", {
      configurable: true,
      enumerable: true,
      get() {
        return require_console();
      }
    });
    Object.defineProperty(exports2, "File", {
      configurable: true,
      enumerable: true,
      get() {
        return require_file();
      }
    });
    Object.defineProperty(exports2, "Http", {
      configurable: true,
      enumerable: true,
      get() {
        return require_http();
      }
    });
    Object.defineProperty(exports2, "Stream", {
      configurable: true,
      enumerable: true,
      get() {
        return require_stream2();
      }
    });
  }
});

// node_modules/winston/lib/winston/config/index.js
var require_config2 = __commonJS({
  "node_modules/winston/lib/winston/config/index.js"(exports2) {
    "use strict";
    var logform = require_logform();
    var { configs } = require_triple_beam();
    exports2.cli = logform.levels(configs.cli);
    exports2.npm = logform.levels(configs.npm);
    exports2.syslog = logform.levels(configs.syslog);
    exports2.addColors = logform.levels;
  }
});

// node_modules/async/eachOf.js
var require_eachOf = __commonJS({
  "node_modules/async/eachOf.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    var _isArrayLike = require_isArrayLike();
    var _isArrayLike2 = _interopRequireDefault(_isArrayLike);
    var _breakLoop = require_breakLoop();
    var _breakLoop2 = _interopRequireDefault(_breakLoop);
    var _eachOfLimit = require_eachOfLimit2();
    var _eachOfLimit2 = _interopRequireDefault(_eachOfLimit);
    var _once = require_once();
    var _once2 = _interopRequireDefault(_once);
    var _onlyOnce = require_onlyOnce();
    var _onlyOnce2 = _interopRequireDefault(_onlyOnce);
    var _wrapAsync = require_wrapAsync();
    var _wrapAsync2 = _interopRequireDefault(_wrapAsync);
    var _awaitify = require_awaitify();
    var _awaitify2 = _interopRequireDefault(_awaitify);
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    function eachOfArrayLike(coll, iteratee, callback) {
      callback = (0, _once2.default)(callback);
      var index = 0, completed = 0, { length } = coll, canceled = false;
      if (length === 0) {
        callback(null);
      }
      function iteratorCallback(err, value) {
        if (err === false) {
          canceled = true;
        }
        if (canceled === true) return;
        if (err) {
          callback(err);
        } else if (++completed === length || value === _breakLoop2.default) {
          callback(null);
        }
      }
      for (; index < length; index++) {
        iteratee(coll[index], index, (0, _onlyOnce2.default)(iteratorCallback));
      }
    }
    function eachOfGeneric(coll, iteratee, callback) {
      return (0, _eachOfLimit2.default)(coll, Infinity, iteratee, callback);
    }
    function eachOf(coll, iteratee, callback) {
      var eachOfImplementation = (0, _isArrayLike2.default)(coll) ? eachOfArrayLike : eachOfGeneric;
      return eachOfImplementation(coll, (0, _wrapAsync2.default)(iteratee), callback);
    }
    exports2.default = (0, _awaitify2.default)(eachOf, 3);
    module2.exports = exports2.default;
  }
});

// node_modules/async/internal/withoutIndex.js
var require_withoutIndex = __commonJS({
  "node_modules/async/internal/withoutIndex.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    exports2.default = _withoutIndex;
    function _withoutIndex(iteratee) {
      return (value, index, callback) => iteratee(value, callback);
    }
    module2.exports = exports2.default;
  }
});

// node_modules/async/forEach.js
var require_forEach = __commonJS({
  "node_modules/async/forEach.js"(exports2, module2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", {
      value: true
    });
    var _eachOf = require_eachOf();
    var _eachOf2 = _interopRequireDefault(_eachOf);
    var _withoutIndex = require_withoutIndex();
    var _withoutIndex2 = _interopRequireDefault(_withoutIndex);
    var _wrapAsync = require_wrapAsync();
    var _wrapAsync2 = _interopRequireDefault(_wrapAsync);
    var _awaitify = require_awaitify();
    var _awaitify2 = _interopRequireDefault(_awaitify);
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { default: obj };
    }
    function eachLimit(coll, iteratee, callback) {
      return (0, _eachOf2.default)(coll, (0, _withoutIndex2.default)((0, _wrapAsync2.default)(iteratee)), callback);
    }
    exports2.default = (0, _awaitify2.default)(eachLimit, 3);
    module2.exports = exports2.default;
  }
});

// node_modules/fn.name/index.js
var require_fn = __commonJS({
  "node_modules/fn.name/index.js"(exports2, module2) {
    "use strict";
    var toString = Object.prototype.toString;
    module2.exports = function name(fn) {
      if ("string" === typeof fn.displayName && fn.constructor.name) {
        return fn.displayName;
      } else if ("string" === typeof fn.name && fn.name) {
        return fn.name;
      }
      if ("object" === typeof fn && fn.constructor && "string" === typeof fn.constructor.name) return fn.constructor.name;
      var named = fn.toString(), type = toString.call(fn).slice(8, -1);
      if ("Function" === type) {
        named = named.substring(named.indexOf("(") + 1, named.indexOf(")"));
      } else {
        named = type;
      }
      return named || "anonymous";
    };
  }
});

// node_modules/one-time/index.js
var require_one_time = __commonJS({
  "node_modules/one-time/index.js"(exports2, module2) {
    "use strict";
    var name = require_fn();
    module2.exports = function one(fn) {
      var called = 0, value;
      function onetime() {
        if (called) return value;
        called = 1;
        value = fn.apply(this, arguments);
        fn = null;
        return value;
      }
      onetime.displayName = name(fn);
      return onetime;
    };
  }
});

// node_modules/stack-trace/lib/stack-trace.js
var require_stack_trace = __commonJS({
  "node_modules/stack-trace/lib/stack-trace.js"(exports2) {
    exports2.get = function(belowFn) {
      var oldLimit = Error.stackTraceLimit;
      Error.stackTraceLimit = Infinity;
      var dummyObject = {};
      var v8Handler = Error.prepareStackTrace;
      Error.prepareStackTrace = function(dummyObject2, v8StackTrace2) {
        return v8StackTrace2;
      };
      Error.captureStackTrace(dummyObject, belowFn || exports2.get);
      var v8StackTrace = dummyObject.stack;
      Error.prepareStackTrace = v8Handler;
      Error.stackTraceLimit = oldLimit;
      return v8StackTrace;
    };
    exports2.parse = function(err) {
      if (!err.stack) {
        return [];
      }
      var self2 = this;
      var lines = err.stack.split("\n").slice(1);
      return lines.map(function(line) {
        if (line.match(/^\s*[-]{4,}$/)) {
          return self2._createParsedCallSite({
            fileName: line,
            lineNumber: null,
            functionName: null,
            typeName: null,
            methodName: null,
            columnNumber: null,
            "native": null
          });
        }
        var lineMatch = line.match(/at (?:(.+)\s+\()?(?:(.+?):(\d+)(?::(\d+))?|([^)]+))\)?/);
        if (!lineMatch) {
          return;
        }
        var object = null;
        var method = null;
        var functionName = null;
        var typeName = null;
        var methodName = null;
        var isNative = lineMatch[5] === "native";
        if (lineMatch[1]) {
          functionName = lineMatch[1];
          var methodStart = functionName.lastIndexOf(".");
          if (functionName[methodStart - 1] == ".")
            methodStart--;
          if (methodStart > 0) {
            object = functionName.substr(0, methodStart);
            method = functionName.substr(methodStart + 1);
            var objectEnd = object.indexOf(".Module");
            if (objectEnd > 0) {
              functionName = functionName.substr(objectEnd + 1);
              object = object.substr(0, objectEnd);
            }
          }
          typeName = null;
        }
        if (method) {
          typeName = object;
          methodName = method;
        }
        if (method === "<anonymous>") {
          methodName = null;
          functionName = null;
        }
        var properties = {
          fileName: lineMatch[2] || null,
          lineNumber: parseInt(lineMatch[3], 10) || null,
          functionName,
          typeName,
          methodName,
          columnNumber: parseInt(lineMatch[4], 10) || null,
          "native": isNative
        };
        return self2._createParsedCallSite(properties);
      }).filter(function(callSite) {
        return !!callSite;
      });
    };
    function CallSite(properties) {
      for (var property in properties) {
        this[property] = properties[property];
      }
    }
    var strProperties = [
      "this",
      "typeName",
      "functionName",
      "methodName",
      "fileName",
      "lineNumber",
      "columnNumber",
      "function",
      "evalOrigin"
    ];
    var boolProperties = [
      "topLevel",
      "eval",
      "native",
      "constructor"
    ];
    strProperties.forEach(function(property) {
      CallSite.prototype[property] = null;
      CallSite.prototype["get" + property[0].toUpperCase() + property.substr(1)] = function() {
        return this[property];
      };
    });
    boolProperties.forEach(function(property) {
      CallSite.prototype[property] = false;
      CallSite.prototype["is" + property[0].toUpperCase() + property.substr(1)] = function() {
        return this[property];
      };
    });
    exports2._createParsedCallSite = function(properties) {
      return new CallSite(properties);
    };
  }
});

// node_modules/winston/lib/winston/exception-stream.js
var require_exception_stream = __commonJS({
  "node_modules/winston/lib/winston/exception-stream.js"(exports2, module2) {
    "use strict";
    var { Writable } = require_readable();
    module2.exports = class ExceptionStream extends Writable {
      /**
       * Constructor function for the ExceptionStream responsible for wrapping a
       * TransportStream; only allowing writes of `info` objects with
       * `info.exception` set to true.
       * @param {!TransportStream} transport - Stream to filter to exceptions
       */
      constructor(transport) {
        super({ objectMode: true });
        if (!transport) {
          throw new Error("ExceptionStream requires a TransportStream instance.");
        }
        this.handleExceptions = true;
        this.transport = transport;
      }
      /**
       * Writes the info object to our transport instance if (and only if) the
       * `exception` property is set on the info.
       * @param {mixed} info - TODO: add param description.
       * @param {mixed} enc - TODO: add param description.
       * @param {mixed} callback - TODO: add param description.
       * @returns {mixed} - TODO: add return description.
       * @private
       */
      _write(info, enc, callback) {
        if (info.exception) {
          return this.transport.log(info, callback);
        }
        callback();
        return true;
      }
    };
  }
});

// node_modules/winston/lib/winston/exception-handler.js
var require_exception_handler = __commonJS({
  "node_modules/winston/lib/winston/exception-handler.js"(exports2, module2) {
    "use strict";
    var os2 = require("os");
    var asyncForEach = require_forEach();
    var debug = require_node2()("winston:exception");
    var once = require_one_time();
    var stackTrace = require_stack_trace();
    var ExceptionStream = require_exception_stream();
    module2.exports = class ExceptionHandler {
      /**
       * TODO: add contructor description
       * @param {!Logger} logger - TODO: add param description
       */
      constructor(logger3) {
        if (!logger3) {
          throw new Error("Logger is required to handle exceptions");
        }
        this.logger = logger3;
        this.handlers = /* @__PURE__ */ new Map();
      }
      /**
       * Handles `uncaughtException` events for the current process by adding any
       * handlers passed in.
       * @returns {undefined}
       */
      handle(...args) {
        args.forEach((arg) => {
          if (Array.isArray(arg)) {
            return arg.forEach((handler) => this._addHandler(handler));
          }
          this._addHandler(arg);
        });
        if (!this.catcher) {
          this.catcher = this._uncaughtException.bind(this);
          process.on("uncaughtException", this.catcher);
        }
      }
      /**
       * Removes any handlers to `uncaughtException` events for the current
       * process. This does not modify the state of the `this.handlers` set.
       * @returns {undefined}
       */
      unhandle() {
        if (this.catcher) {
          process.removeListener("uncaughtException", this.catcher);
          this.catcher = false;
          Array.from(this.handlers.values()).forEach((wrapper) => this.logger.unpipe(wrapper));
        }
      }
      /**
       * TODO: add method description
       * @param {Error} err - Error to get information about.
       * @returns {mixed} - TODO: add return description.
       */
      getAllInfo(err) {
        let message = null;
        if (err) {
          message = typeof err === "string" ? err : err.message;
        }
        return {
          error: err,
          // TODO (indexzero): how do we configure this?
          level: "error",
          message: [
            `uncaughtException: ${message || "(no error message)"}`,
            err && err.stack || "  No stack trace"
          ].join("\n"),
          stack: err && err.stack,
          exception: true,
          date: (/* @__PURE__ */ new Date()).toString(),
          process: this.getProcessInfo(),
          os: this.getOsInfo(),
          trace: this.getTrace(err)
        };
      }
      /**
       * Gets all relevant process information for the currently running process.
       * @returns {mixed} - TODO: add return description.
       */
      getProcessInfo() {
        return {
          pid: process.pid,
          uid: process.getuid ? process.getuid() : null,
          gid: process.getgid ? process.getgid() : null,
          cwd: process.cwd(),
          execPath: process.execPath,
          version: process.version,
          argv: process.argv,
          memoryUsage: process.memoryUsage()
        };
      }
      /**
       * Gets all relevant OS information for the currently running process.
       * @returns {mixed} - TODO: add return description.
       */
      getOsInfo() {
        return {
          loadavg: os2.loadavg(),
          uptime: os2.uptime()
        };
      }
      /**
       * Gets a stack trace for the specified error.
       * @param {mixed} err - TODO: add param description.
       * @returns {mixed} - TODO: add return description.
       */
      getTrace(err) {
        const trace = err ? stackTrace.parse(err) : stackTrace.get();
        return trace.map((site) => {
          return {
            column: site.getColumnNumber(),
            file: site.getFileName(),
            function: site.getFunctionName(),
            line: site.getLineNumber(),
            method: site.getMethodName(),
            native: site.isNative()
          };
        });
      }
      /**
       * Helper method to add a transport as an exception handler.
       * @param {Transport} handler - The transport to add as an exception handler.
       * @returns {void}
       */
      _addHandler(handler) {
        if (!this.handlers.has(handler)) {
          handler.handleExceptions = true;
          const wrapper = new ExceptionStream(handler);
          this.handlers.set(handler, wrapper);
          this.logger.pipe(wrapper);
        }
      }
      /**
       * Logs all relevant information around the `err` and exits the current
       * process.
       * @param {Error} err - Error to handle
       * @returns {mixed} - TODO: add return description.
       * @private
       */
      _uncaughtException(err) {
        const info = this.getAllInfo(err);
        const handlers = this._getExceptionHandlers();
        let doExit = typeof this.logger.exitOnError === "function" ? this.logger.exitOnError(err) : this.logger.exitOnError;
        let timeout;
        if (!handlers.length && doExit) {
          console.warn("winston: exitOnError cannot be true with no exception handlers.");
          console.warn("winston: not exiting process.");
          doExit = false;
        }
        function gracefulExit() {
          debug("doExit", doExit);
          debug("process._exiting", process._exiting);
          if (doExit && !process._exiting) {
            if (timeout) {
              clearTimeout(timeout);
            }
            process.exit(1);
          }
        }
        if (!handlers || handlers.length === 0) {
          return process.nextTick(gracefulExit);
        }
        asyncForEach(handlers, (handler, next) => {
          const done = once(next);
          const transport = handler.transport || handler;
          function onDone(event) {
            return () => {
              debug(event);
              done();
            };
          }
          transport._ending = true;
          transport.once("finish", onDone("finished"));
          transport.once("error", onDone("error"));
        }, () => doExit && gracefulExit());
        this.logger.log(info);
        if (doExit) {
          timeout = setTimeout(gracefulExit, 3e3);
        }
      }
      /**
       * Returns the list of transports and exceptionHandlers for this instance.
       * @returns {Array} - List of transports and exceptionHandlers for this
       * instance.
       * @private
       */
      _getExceptionHandlers() {
        return this.logger.transports.filter((wrap) => {
          const transport = wrap.transport || wrap;
          return transport.handleExceptions;
        });
      }
    };
  }
});

// node_modules/winston/lib/winston/rejection-stream.js
var require_rejection_stream = __commonJS({
  "node_modules/winston/lib/winston/rejection-stream.js"(exports2, module2) {
    "use strict";
    var { Writable } = require_readable();
    module2.exports = class RejectionStream extends Writable {
      /**
       * Constructor function for the RejectionStream responsible for wrapping a
       * TransportStream; only allowing writes of `info` objects with
       * `info.rejection` set to true.
       * @param {!TransportStream} transport - Stream to filter to rejections
       */
      constructor(transport) {
        super({ objectMode: true });
        if (!transport) {
          throw new Error("RejectionStream requires a TransportStream instance.");
        }
        this.handleRejections = true;
        this.transport = transport;
      }
      /**
       * Writes the info object to our transport instance if (and only if) the
       * `rejection` property is set on the info.
       * @param {mixed} info - TODO: add param description.
       * @param {mixed} enc - TODO: add param description.
       * @param {mixed} callback - TODO: add param description.
       * @returns {mixed} - TODO: add return description.
       * @private
       */
      _write(info, enc, callback) {
        if (info.rejection) {
          return this.transport.log(info, callback);
        }
        callback();
        return true;
      }
    };
  }
});

// node_modules/winston/lib/winston/rejection-handler.js
var require_rejection_handler = __commonJS({
  "node_modules/winston/lib/winston/rejection-handler.js"(exports2, module2) {
    "use strict";
    var os2 = require("os");
    var asyncForEach = require_forEach();
    var debug = require_node2()("winston:rejection");
    var once = require_one_time();
    var stackTrace = require_stack_trace();
    var RejectionStream = require_rejection_stream();
    module2.exports = class RejectionHandler {
      /**
       * TODO: add contructor description
       * @param {!Logger} logger - TODO: add param description
       */
      constructor(logger3) {
        if (!logger3) {
          throw new Error("Logger is required to handle rejections");
        }
        this.logger = logger3;
        this.handlers = /* @__PURE__ */ new Map();
      }
      /**
       * Handles `unhandledRejection` events for the current process by adding any
       * handlers passed in.
       * @returns {undefined}
       */
      handle(...args) {
        args.forEach((arg) => {
          if (Array.isArray(arg)) {
            return arg.forEach((handler) => this._addHandler(handler));
          }
          this._addHandler(arg);
        });
        if (!this.catcher) {
          this.catcher = this._unhandledRejection.bind(this);
          process.on("unhandledRejection", this.catcher);
        }
      }
      /**
       * Removes any handlers to `unhandledRejection` events for the current
       * process. This does not modify the state of the `this.handlers` set.
       * @returns {undefined}
       */
      unhandle() {
        if (this.catcher) {
          process.removeListener("unhandledRejection", this.catcher);
          this.catcher = false;
          Array.from(this.handlers.values()).forEach(
            (wrapper) => this.logger.unpipe(wrapper)
          );
        }
      }
      /**
       * TODO: add method description
       * @param {Error} err - Error to get information about.
       * @returns {mixed} - TODO: add return description.
       */
      getAllInfo(err) {
        let message = null;
        if (err) {
          message = typeof err === "string" ? err : err.message;
        }
        return {
          error: err,
          // TODO (indexzero): how do we configure this?
          level: "error",
          message: [
            `unhandledRejection: ${message || "(no error message)"}`,
            err && err.stack || "  No stack trace"
          ].join("\n"),
          stack: err && err.stack,
          rejection: true,
          date: (/* @__PURE__ */ new Date()).toString(),
          process: this.getProcessInfo(),
          os: this.getOsInfo(),
          trace: this.getTrace(err)
        };
      }
      /**
       * Gets all relevant process information for the currently running process.
       * @returns {mixed} - TODO: add return description.
       */
      getProcessInfo() {
        return {
          pid: process.pid,
          uid: process.getuid ? process.getuid() : null,
          gid: process.getgid ? process.getgid() : null,
          cwd: process.cwd(),
          execPath: process.execPath,
          version: process.version,
          argv: process.argv,
          memoryUsage: process.memoryUsage()
        };
      }
      /**
       * Gets all relevant OS information for the currently running process.
       * @returns {mixed} - TODO: add return description.
       */
      getOsInfo() {
        return {
          loadavg: os2.loadavg(),
          uptime: os2.uptime()
        };
      }
      /**
       * Gets a stack trace for the specified error.
       * @param {mixed} err - TODO: add param description.
       * @returns {mixed} - TODO: add return description.
       */
      getTrace(err) {
        const trace = err ? stackTrace.parse(err) : stackTrace.get();
        return trace.map((site) => {
          return {
            column: site.getColumnNumber(),
            file: site.getFileName(),
            function: site.getFunctionName(),
            line: site.getLineNumber(),
            method: site.getMethodName(),
            native: site.isNative()
          };
        });
      }
      /**
       * Helper method to add a transport as an exception handler.
       * @param {Transport} handler - The transport to add as an exception handler.
       * @returns {void}
       */
      _addHandler(handler) {
        if (!this.handlers.has(handler)) {
          handler.handleRejections = true;
          const wrapper = new RejectionStream(handler);
          this.handlers.set(handler, wrapper);
          this.logger.pipe(wrapper);
        }
      }
      /**
       * Logs all relevant information around the `err` and exits the current
       * process.
       * @param {Error} err - Error to handle
       * @returns {mixed} - TODO: add return description.
       * @private
       */
      _unhandledRejection(err) {
        const info = this.getAllInfo(err);
        const handlers = this._getRejectionHandlers();
        let doExit = typeof this.logger.exitOnError === "function" ? this.logger.exitOnError(err) : this.logger.exitOnError;
        let timeout;
        if (!handlers.length && doExit) {
          console.warn("winston: exitOnError cannot be true with no rejection handlers.");
          console.warn("winston: not exiting process.");
          doExit = false;
        }
        function gracefulExit() {
          debug("doExit", doExit);
          debug("process._exiting", process._exiting);
          if (doExit && !process._exiting) {
            if (timeout) {
              clearTimeout(timeout);
            }
            process.exit(1);
          }
        }
        if (!handlers || handlers.length === 0) {
          return process.nextTick(gracefulExit);
        }
        asyncForEach(
          handlers,
          (handler, next) => {
            const done = once(next);
            const transport = handler.transport || handler;
            function onDone(event) {
              return () => {
                debug(event);
                done();
              };
            }
            transport._ending = true;
            transport.once("finish", onDone("finished"));
            transport.once("error", onDone("error"));
          },
          () => doExit && gracefulExit()
        );
        this.logger.log(info);
        if (doExit) {
          timeout = setTimeout(gracefulExit, 3e3);
        }
      }
      /**
       * Returns the list of transports and exceptionHandlers for this instance.
       * @returns {Array} - List of transports and exceptionHandlers for this
       * instance.
       * @private
       */
      _getRejectionHandlers() {
        return this.logger.transports.filter((wrap) => {
          const transport = wrap.transport || wrap;
          return transport.handleRejections;
        });
      }
    };
  }
});

// node_modules/winston/lib/winston/profiler.js
var require_profiler = __commonJS({
  "node_modules/winston/lib/winston/profiler.js"(exports2, module2) {
    "use strict";
    var Profiler = class {
      /**
       * Constructor function for the Profiler instance used by
       * `Logger.prototype.startTimer`. When done is called the timer will finish
       * and log the duration.
       * @param {!Logger} logger - TODO: add param description.
       * @private
       */
      constructor(logger3) {
        const Logger = require_logger();
        if (typeof logger3 !== "object" || Array.isArray(logger3) || !(logger3 instanceof Logger)) {
          throw new Error("Logger is required for profiling");
        } else {
          this.logger = logger3;
          this.start = Date.now();
        }
      }
      /**
       * Ends the current timer (i.e. Profiler) instance and logs the `msg` along
       * with the duration since creation.
       * @returns {mixed} - TODO: add return description.
       * @private
       */
      done(...args) {
        if (typeof args[args.length - 1] === "function") {
          console.warn("Callback function no longer supported as of winston@3.0.0");
          args.pop();
        }
        const info = typeof args[args.length - 1] === "object" ? args.pop() : {};
        info.level = info.level || "info";
        info.durationMs = Date.now() - this.start;
        return this.logger.write(info);
      }
    };
    module2.exports = Profiler;
  }
});

// node_modules/winston/lib/winston/logger.js
var require_logger = __commonJS({
  "node_modules/winston/lib/winston/logger.js"(exports2, module2) {
    "use strict";
    var { Stream, Transform } = require_readable();
    var asyncForEach = require_forEach();
    var { LEVEL, SPLAT } = require_triple_beam();
    var isStream = require_is_stream();
    var ExceptionHandler = require_exception_handler();
    var RejectionHandler = require_rejection_handler();
    var LegacyTransportStream = require_legacy();
    var Profiler = require_profiler();
    var { warn } = require_common();
    var config = require_config2();
    var formatRegExp = /%[scdjifoO%]/g;
    var Logger = class extends Transform {
      /**
       * Constructor function for the Logger object responsible for persisting log
       * messages and metadata to one or more transports.
       * @param {!Object} options - foo
       */
      constructor(options) {
        super({ objectMode: true });
        this.configure(options);
      }
      child(defaultRequestMetadata) {
        const logger3 = this;
        return Object.create(logger3, {
          write: {
            value: function(info) {
              const infoClone = Object.assign(
                {},
                defaultRequestMetadata,
                info
              );
              if (info instanceof Error) {
                infoClone.stack = info.stack;
                infoClone.message = info.message;
                infoClone.cause = info.cause;
              }
              logger3.write(infoClone);
            }
          }
        });
      }
      /**
       * This will wholesale reconfigure this instance by:
       * 1. Resetting all transports. Older transports will be removed implicitly.
       * 2. Set all other options including levels, colors, rewriters, filters,
       *    exceptionHandlers, etc.
       * @param {!Object} options - TODO: add param description.
       * @returns {undefined}
       */
      configure({
        silent,
        format,
        defaultMeta,
        levels,
        level = "info",
        exitOnError = true,
        transports,
        colors,
        emitErrs,
        formatters,
        padLevels,
        rewriters,
        stripColors,
        exceptionHandlers,
        rejectionHandlers
      } = {}) {
        if (this.transports.length) {
          this.clear();
        }
        this.silent = silent;
        this.format = format || this.format || require_json()();
        this.defaultMeta = defaultMeta || null;
        this.levels = levels || this.levels || config.npm.levels;
        this.level = level;
        if (this.exceptions) {
          this.exceptions.unhandle();
        }
        if (this.rejections) {
          this.rejections.unhandle();
        }
        this.exceptions = new ExceptionHandler(this);
        this.rejections = new RejectionHandler(this);
        this.profilers = {};
        this.exitOnError = exitOnError;
        if (transports) {
          transports = Array.isArray(transports) ? transports : [transports];
          transports.forEach((transport) => this.add(transport));
        }
        if (colors || emitErrs || formatters || padLevels || rewriters || stripColors) {
          throw new Error(
            [
              "{ colors, emitErrs, formatters, padLevels, rewriters, stripColors } were removed in winston@3.0.0.",
              "Use a custom winston.format(function) instead.",
              "See: https://github.com/winstonjs/winston/tree/master/UPGRADE-3.0.md"
            ].join("\n")
          );
        }
        if (exceptionHandlers) {
          this.exceptions.handle(exceptionHandlers);
        }
        if (rejectionHandlers) {
          this.rejections.handle(rejectionHandlers);
        }
      }
      /* eslint-disable valid-jsdoc */
      /**
       * Helper method to get the highest logging level associated with a logger
       *
       * @returns { number | null } - The highest configured logging level, null
       * for invalid configuration
       */
      getHighestLogLevel() {
        const configuredLevelValue = getLevelValue(this.levels, this.level);
        if (!this.transports || this.transports.length === 0) {
          return configuredLevelValue;
        }
        return this.transports.reduce((max, transport) => {
          const levelValue = getLevelValue(this.levels, transport.level);
          return levelValue !== null && levelValue > max ? levelValue : max;
        }, configuredLevelValue);
      }
      isLevelEnabled(level) {
        const givenLevelValue = getLevelValue(this.levels, level);
        if (givenLevelValue === null) {
          return false;
        }
        const configuredLevelValue = getLevelValue(this.levels, this.level);
        if (configuredLevelValue === null) {
          return false;
        }
        if (!this.transports || this.transports.length === 0) {
          return configuredLevelValue >= givenLevelValue;
        }
        const index = this.transports.findIndex((transport) => {
          let transportLevelValue = getLevelValue(this.levels, transport.level);
          if (transportLevelValue === null) {
            transportLevelValue = configuredLevelValue;
          }
          return transportLevelValue >= givenLevelValue;
        });
        return index !== -1;
      }
      /* eslint-disable valid-jsdoc */
      /**
       * Ensure backwards compatibility with a `log` method
       * @param {mixed} level - Level the log message is written at.
       * @param {mixed} msg - TODO: add param description.
       * @param {mixed} meta - TODO: add param description.
       * @returns {Logger} - TODO: add return description.
       *
       * @example
       *    // Supports the existing API:
       *    logger.log('info', 'Hello world', { custom: true });
       *    logger.log('info', new Error('Yo, it\'s on fire'));
       *
       *    // Requires winston.format.splat()
       *    logger.log('info', '%s %d%%', 'A string', 50, { thisIsMeta: true });
       *
       *    // And the new API with a single JSON literal:
       *    logger.log({ level: 'info', message: 'Hello world', custom: true });
       *    logger.log({ level: 'info', message: new Error('Yo, it\'s on fire') });
       *
       *    // Also requires winston.format.splat()
       *    logger.log({
       *      level: 'info',
       *      message: '%s %d%%',
       *      [SPLAT]: ['A string', 50],
       *      meta: { thisIsMeta: true }
       *    });
       *
       */
      /* eslint-enable valid-jsdoc */
      log(level, msg, ...splat) {
        if (arguments.length === 1) {
          level[LEVEL] = level.level;
          this._addDefaultMeta(level);
          this.write(level);
          return this;
        }
        if (arguments.length === 2) {
          if (msg && typeof msg === "object") {
            msg[LEVEL] = msg.level = level;
            this._addDefaultMeta(msg);
            this.write(msg);
            return this;
          }
          msg = { [LEVEL]: level, level, message: msg };
          this._addDefaultMeta(msg);
          this.write(msg);
          return this;
        }
        const [meta] = splat;
        if (typeof meta === "object" && meta !== null) {
          const tokens = msg && msg.match && msg.match(formatRegExp);
          if (!tokens) {
            const info = Object.assign({}, this.defaultMeta, meta, {
              [LEVEL]: level,
              [SPLAT]: splat,
              level,
              message: msg
            });
            if (meta.message) info.message = `${info.message} ${meta.message}`;
            if (meta.stack) info.stack = meta.stack;
            if (meta.cause) info.cause = meta.cause;
            this.write(info);
            return this;
          }
        }
        this.write(Object.assign({}, this.defaultMeta, {
          [LEVEL]: level,
          [SPLAT]: splat,
          level,
          message: msg
        }));
        return this;
      }
      /**
       * Pushes data so that it can be picked up by all of our pipe targets.
       * @param {mixed} info - TODO: add param description.
       * @param {mixed} enc - TODO: add param description.
       * @param {mixed} callback - Continues stream processing.
       * @returns {undefined}
       * @private
       */
      _transform(info, enc, callback) {
        if (this.silent) {
          return callback();
        }
        if (!info[LEVEL]) {
          info[LEVEL] = info.level;
        }
        if (!this.levels[info[LEVEL]] && this.levels[info[LEVEL]] !== 0) {
          console.error("[winston] Unknown logger level: %s", info[LEVEL]);
        }
        if (!this._readableState.pipes) {
          console.error(
            "[winston] Attempt to write logs with no transports, which can increase memory usage: %j",
            info
          );
        }
        try {
          this.push(this.format.transform(info, this.format.options));
        } finally {
          this._writableState.sync = false;
          callback();
        }
      }
      /**
       * Delays the 'finish' event until all transport pipe targets have
       * also emitted 'finish' or are already finished.
       * @param {mixed} callback - Continues stream processing.
       */
      _final(callback) {
        const transports = this.transports.slice();
        asyncForEach(
          transports,
          (transport, next) => {
            if (!transport || transport.finished) return setImmediate(next);
            transport.once("finish", next);
            transport.end();
          },
          callback
        );
      }
      /**
       * Adds the transport to this logger instance by piping to it.
       * @param {mixed} transport - TODO: add param description.
       * @returns {Logger} - TODO: add return description.
       */
      add(transport) {
        const target = !isStream(transport) || transport.log.length > 2 ? new LegacyTransportStream({ transport }) : transport;
        if (!target._writableState || !target._writableState.objectMode) {
          throw new Error(
            "Transports must WritableStreams in objectMode. Set { objectMode: true }."
          );
        }
        this._onEvent("error", target);
        this._onEvent("warn", target);
        this.pipe(target);
        if (transport.handleExceptions) {
          this.exceptions.handle();
        }
        if (transport.handleRejections) {
          this.rejections.handle();
        }
        return this;
      }
      /**
       * Removes the transport from this logger instance by unpiping from it.
       * @param {mixed} transport - TODO: add param description.
       * @returns {Logger} - TODO: add return description.
       */
      remove(transport) {
        if (!transport) return this;
        let target = transport;
        if (!isStream(transport) || transport.log.length > 2) {
          target = this.transports.filter(
            (match) => match.transport === transport
          )[0];
        }
        if (target) {
          this.unpipe(target);
        }
        return this;
      }
      /**
       * Removes all transports from this logger instance.
       * @returns {Logger} - TODO: add return description.
       */
      clear() {
        this.unpipe();
        return this;
      }
      /**
       * Cleans up resources (streams, event listeners) for all transports
       * associated with this instance (if necessary).
       * @returns {Logger} - TODO: add return description.
       */
      close() {
        this.exceptions.unhandle();
        this.rejections.unhandle();
        this.clear();
        this.emit("close");
        return this;
      }
      /**
       * Sets the `target` levels specified on this instance.
       * @param {Object} Target levels to use on this instance.
       */
      setLevels() {
        warn.deprecated("setLevels");
      }
      /**
       * Queries the all transports for this instance with the specified `options`.
       * This will aggregate each transport's results into one object containing
       * a property per transport.
       * @param {Object} options - Query options for this instance.
       * @param {function} callback - Continuation to respond to when complete.
       */
      query(options, callback) {
        if (typeof options === "function") {
          callback = options;
          options = {};
        }
        options = options || {};
        const results = {};
        const queryObject = Object.assign({}, options.query || {});
        function queryTransport(transport, next) {
          if (options.query && typeof transport.formatQuery === "function") {
            options.query = transport.formatQuery(queryObject);
          }
          transport.query(options, (err, res) => {
            if (err) {
              return next(err);
            }
            if (typeof transport.formatResults === "function") {
              res = transport.formatResults(res, options.format);
            }
            next(null, res);
          });
        }
        function addResults(transport, next) {
          queryTransport(transport, (err, result) => {
            if (next) {
              result = err || result;
              if (result) {
                results[transport.name] = result;
              }
              next();
            }
            next = null;
          });
        }
        asyncForEach(
          this.transports.filter((transport) => !!transport.query),
          addResults,
          () => callback(null, results)
        );
      }
      /**
       * Returns a log stream for all transports. Options object is optional.
       * @param{Object} options={} - Stream options for this instance.
       * @returns {Stream} - TODO: add return description.
       */
      stream(options = {}) {
        const out = new Stream();
        const streams = [];
        out._streams = streams;
        out.destroy = () => {
          let i = streams.length;
          while (i--) {
            streams[i].destroy();
          }
        };
        this.transports.filter((transport) => !!transport.stream).forEach((transport) => {
          const str = transport.stream(options);
          if (!str) {
            return;
          }
          streams.push(str);
          str.on("log", (log) => {
            log.transport = log.transport || [];
            log.transport.push(transport.name);
            out.emit("log", log);
          });
          str.on("error", (err) => {
            err.transport = err.transport || [];
            err.transport.push(transport.name);
            out.emit("error", err);
          });
        });
        return out;
      }
      /**
       * Returns an object corresponding to a specific timing. When done is called
       * the timer will finish and log the duration. e.g.:
       * @returns {Profile} - TODO: add return description.
       * @example
       *    const timer = winston.startTimer()
       *    setTimeout(() => {
       *      timer.done({
       *        message: 'Logging message'
       *      });
       *    }, 1000);
       */
      startTimer() {
        return new Profiler(this);
      }
      /**
       * Tracks the time inbetween subsequent calls to this method with the same
       * `id` parameter. The second call to this method will log the difference in
       * milliseconds along with the message.
       * @param {string} id Unique id of the profiler
       * @returns {Logger} - TODO: add return description.
       */
      profile(id, ...args) {
        const time = Date.now();
        if (this.profilers[id]) {
          const timeEnd = this.profilers[id];
          delete this.profilers[id];
          if (typeof args[args.length - 2] === "function") {
            console.warn(
              "Callback function no longer supported as of winston@3.0.0"
            );
            args.pop();
          }
          const info = typeof args[args.length - 1] === "object" ? args.pop() : {};
          info.level = info.level || "info";
          info.durationMs = time - timeEnd;
          info.message = info.message || id;
          return this.write(info);
        }
        this.profilers[id] = time;
        return this;
      }
      /**
       * Backwards compatibility to `exceptions.handle` in winston < 3.0.0.
       * @returns {undefined}
       * @deprecated
       */
      handleExceptions(...args) {
        console.warn(
          "Deprecated: .handleExceptions() will be removed in winston@4. Use .exceptions.handle()"
        );
        this.exceptions.handle(...args);
      }
      /**
       * Backwards compatibility to `exceptions.handle` in winston < 3.0.0.
       * @returns {undefined}
       * @deprecated
       */
      unhandleExceptions(...args) {
        console.warn(
          "Deprecated: .unhandleExceptions() will be removed in winston@4. Use .exceptions.unhandle()"
        );
        this.exceptions.unhandle(...args);
      }
      /**
       * Throw a more meaningful deprecation notice
       * @throws {Error} - TODO: add throws description.
       */
      cli() {
        throw new Error(
          [
            "Logger.cli() was removed in winston@3.0.0",
            "Use a custom winston.formats.cli() instead.",
            "See: https://github.com/winstonjs/winston/tree/master/UPGRADE-3.0.md"
          ].join("\n")
        );
      }
      /**
       * Bubbles the `event` that occured on the specified `transport` up
       * from this instance.
       * @param {string} event - The event that occured
       * @param {Object} transport - Transport on which the event occured
       * @private
       */
      _onEvent(event, transport) {
        function transportEvent(err) {
          if (event === "error" && !this.transports.includes(transport)) {
            this.add(transport);
          }
          this.emit(event, err, transport);
        }
        if (!transport["__winston" + event]) {
          transport["__winston" + event] = transportEvent.bind(this);
          transport.on(event, transport["__winston" + event]);
        }
      }
      _addDefaultMeta(msg) {
        if (this.defaultMeta) {
          Object.assign(msg, this.defaultMeta);
        }
      }
    };
    function getLevelValue(levels, level) {
      const value = levels[level];
      if (!value && value !== 0) {
        return null;
      }
      return value;
    }
    Object.defineProperty(Logger.prototype, "transports", {
      configurable: false,
      enumerable: true,
      get() {
        const { pipes } = this._readableState;
        return !Array.isArray(pipes) ? [pipes].filter(Boolean) : pipes;
      }
    });
    module2.exports = Logger;
  }
});

// node_modules/winston/lib/winston/create-logger.js
var require_create_logger = __commonJS({
  "node_modules/winston/lib/winston/create-logger.js"(exports2, module2) {
    "use strict";
    var { LEVEL } = require_triple_beam();
    var config = require_config2();
    var Logger = require_logger();
    var debug = require_node2()("winston:create-logger");
    function isLevelEnabledFunctionName(level) {
      return "is" + level.charAt(0).toUpperCase() + level.slice(1) + "Enabled";
    }
    module2.exports = function(opts = {}) {
      opts.levels = opts.levels || config.npm.levels;
      class DerivedLogger extends Logger {
        /**
         * Create a new class derived logger for which the levels can be attached to
         * the prototype of. This is a V8 optimization that is well know to increase
         * performance of prototype functions.
         * @param {!Object} options - Options for the created logger.
         */
        constructor(options) {
          super(options);
        }
      }
      const logger3 = new DerivedLogger(opts);
      Object.keys(opts.levels).forEach(function(level) {
        debug('Define prototype method for "%s"', level);
        if (level === "log") {
          console.warn('Level "log" not defined: conflicts with the method "log". Use a different level name.');
          return;
        }
        DerivedLogger.prototype[level] = function(...args) {
          const self2 = this || logger3;
          if (args.length === 1) {
            const [msg] = args;
            const info = msg && msg.message && msg || { message: msg };
            info.level = info[LEVEL] = level;
            self2._addDefaultMeta(info);
            self2.write(info);
            return this || logger3;
          }
          if (args.length === 0) {
            self2.log(level, "");
            return self2;
          }
          return self2.log(level, ...args);
        };
        DerivedLogger.prototype[isLevelEnabledFunctionName(level)] = function() {
          return (this || logger3).isLevelEnabled(level);
        };
      });
      return logger3;
    };
  }
});

// node_modules/winston/lib/winston/container.js
var require_container = __commonJS({
  "node_modules/winston/lib/winston/container.js"(exports2, module2) {
    "use strict";
    var createLogger = require_create_logger();
    module2.exports = class Container {
      /**
       * Constructor function for the Container object responsible for managing a
       * set of `winston.Logger` instances based on string ids.
       * @param {!Object} [options={}] - Default pass-thru options for Loggers.
       */
      constructor(options = {}) {
        this.loggers = /* @__PURE__ */ new Map();
        this.options = options;
      }
      /**
       * Retrieves a `winston.Logger` instance for the specified `id`. If an
       * instance does not exist, one is created.
       * @param {!string} id - The id of the Logger to get.
       * @param {?Object} [options] - Options for the Logger instance.
       * @returns {Logger} - A configured Logger instance with a specified id.
       */
      add(id, options) {
        if (!this.loggers.has(id)) {
          options = Object.assign({}, options || this.options);
          const existing = options.transports || this.options.transports;
          if (existing) {
            options.transports = Array.isArray(existing) ? existing.slice() : [existing];
          } else {
            options.transports = [];
          }
          const logger3 = createLogger(options);
          logger3.on("close", () => this._delete(id));
          this.loggers.set(id, logger3);
        }
        return this.loggers.get(id);
      }
      /**
       * Retreives a `winston.Logger` instance for the specified `id`. If
       * an instance does not exist, one is created.
       * @param {!string} id - The id of the Logger to get.
       * @param {?Object} [options] - Options for the Logger instance.
       * @returns {Logger} - A configured Logger instance with a specified id.
       */
      get(id, options) {
        return this.add(id, options);
      }
      /**
       * Check if the container has a logger with the id.
       * @param {?string} id - The id of the Logger instance to find.
       * @returns {boolean} - Boolean value indicating if this instance has a
       * logger with the specified `id`.
       */
      has(id) {
        return !!this.loggers.has(id);
      }
      /**
       * Closes a `Logger` instance with the specified `id` if it exists.
       * If no `id` is supplied then all Loggers are closed.
       * @param {?string} id - The id of the Logger instance to close.
       * @returns {undefined}
       */
      close(id) {
        if (id) {
          return this._removeLogger(id);
        }
        this.loggers.forEach((val, key) => this._removeLogger(key));
      }
      /**
       * Remove a logger based on the id.
       * @param {!string} id - The id of the logger to remove.
       * @returns {undefined}
       * @private
       */
      _removeLogger(id) {
        if (!this.loggers.has(id)) {
          return;
        }
        const logger3 = this.loggers.get(id);
        logger3.close();
        this._delete(id);
      }
      /**
       * Deletes a `Logger` instance with the specified `id`.
       * @param {!string} id - The id of the Logger instance to delete from
       * container.
       * @returns {undefined}
       * @private
       */
      _delete(id) {
        this.loggers.delete(id);
      }
    };
  }
});

// node_modules/winston/lib/winston.js
var require_winston = __commonJS({
  "node_modules/winston/lib/winston.js"(exports2) {
    "use strict";
    var logform = require_logform();
    var { warn } = require_common();
    exports2.version = require_package().version;
    exports2.transports = require_transports();
    exports2.config = require_config2();
    exports2.addColors = logform.levels;
    exports2.format = logform.format;
    exports2.createLogger = require_create_logger();
    exports2.Logger = require_logger();
    exports2.ExceptionHandler = require_exception_handler();
    exports2.RejectionHandler = require_rejection_handler();
    exports2.Container = require_container();
    exports2.Transport = require_winston_transport();
    exports2.loggers = new exports2.Container();
    var defaultLogger = exports2.createLogger();
    Object.keys(exports2.config.npm.levels).concat([
      "log",
      "query",
      "stream",
      "add",
      "remove",
      "clear",
      "profile",
      "startTimer",
      "handleExceptions",
      "unhandleExceptions",
      "handleRejections",
      "unhandleRejections",
      "configure",
      "child"
    ]).forEach(
      (method) => exports2[method] = (...args) => defaultLogger[method](...args)
    );
    Object.defineProperty(exports2, "level", {
      get() {
        return defaultLogger.level;
      },
      set(val) {
        defaultLogger.level = val;
      }
    });
    Object.defineProperty(exports2, "exceptions", {
      get() {
        return defaultLogger.exceptions;
      }
    });
    Object.defineProperty(exports2, "rejections", {
      get() {
        return defaultLogger.rejections;
      }
    });
    ["exitOnError"].forEach((prop) => {
      Object.defineProperty(exports2, prop, {
        get() {
          return defaultLogger[prop];
        },
        set(val) {
          defaultLogger[prop] = val;
        }
      });
    });
    Object.defineProperty(exports2, "default", {
      get() {
        return {
          exceptionHandlers: defaultLogger.exceptionHandlers,
          rejectionHandlers: defaultLogger.rejectionHandlers,
          transports: defaultLogger.transports
        };
      }
    });
    warn.deprecated(exports2, "setLevels");
    warn.forFunctions(exports2, "useFormat", ["cli"]);
    warn.forProperties(exports2, "useFormat", ["padLevels", "stripColors"]);
    warn.forFunctions(exports2, "deprecated", [
      "addRewriter",
      "addFilter",
      "clone",
      "extend"
    ]);
    warn.forProperties(exports2, "deprecated", ["emitErrs", "levelLength"]);
  }
});

// node_modules/object-hash/index.js
var require_object_hash = __commonJS({
  "node_modules/object-hash/index.js"(exports2, module2) {
    "use strict";
    var crypto = require("crypto");
    exports2 = module2.exports = objectHash;
    function objectHash(object, options) {
      options = applyDefaults(object, options);
      return hash(object, options);
    }
    exports2.sha1 = function(object) {
      return objectHash(object);
    };
    exports2.keys = function(object) {
      return objectHash(object, { excludeValues: true, algorithm: "sha1", encoding: "hex" });
    };
    exports2.MD5 = function(object) {
      return objectHash(object, { algorithm: "md5", encoding: "hex" });
    };
    exports2.keysMD5 = function(object) {
      return objectHash(object, { algorithm: "md5", encoding: "hex", excludeValues: true });
    };
    var hashes = crypto.getHashes ? crypto.getHashes().slice() : ["sha1", "md5"];
    hashes.push("passthrough");
    var encodings = ["buffer", "hex", "binary", "base64"];
    function applyDefaults(object, sourceOptions) {
      sourceOptions = sourceOptions || {};
      var options = {};
      options.algorithm = sourceOptions.algorithm || "sha1";
      options.encoding = sourceOptions.encoding || "hex";
      options.excludeValues = sourceOptions.excludeValues ? true : false;
      options.algorithm = options.algorithm.toLowerCase();
      options.encoding = options.encoding.toLowerCase();
      options.ignoreUnknown = sourceOptions.ignoreUnknown !== true ? false : true;
      options.respectType = sourceOptions.respectType === false ? false : true;
      options.respectFunctionNames = sourceOptions.respectFunctionNames === false ? false : true;
      options.respectFunctionProperties = sourceOptions.respectFunctionProperties === false ? false : true;
      options.unorderedArrays = sourceOptions.unorderedArrays !== true ? false : true;
      options.unorderedSets = sourceOptions.unorderedSets === false ? false : true;
      options.unorderedObjects = sourceOptions.unorderedObjects === false ? false : true;
      options.replacer = sourceOptions.replacer || void 0;
      options.excludeKeys = sourceOptions.excludeKeys || void 0;
      if (typeof object === "undefined") {
        throw new Error("Object argument required.");
      }
      for (var i = 0; i < hashes.length; ++i) {
        if (hashes[i].toLowerCase() === options.algorithm.toLowerCase()) {
          options.algorithm = hashes[i];
        }
      }
      if (hashes.indexOf(options.algorithm) === -1) {
        throw new Error('Algorithm "' + options.algorithm + '"  not supported. supported values: ' + hashes.join(", "));
      }
      if (encodings.indexOf(options.encoding) === -1 && options.algorithm !== "passthrough") {
        throw new Error('Encoding "' + options.encoding + '"  not supported. supported values: ' + encodings.join(", "));
      }
      return options;
    }
    function isNativeFunction(f) {
      if (typeof f !== "function") {
        return false;
      }
      var exp = /^function\s+\w*\s*\(\s*\)\s*{\s+\[native code\]\s+}$/i;
      return exp.exec(Function.prototype.toString.call(f)) != null;
    }
    function hash(object, options) {
      var hashingStream;
      if (options.algorithm !== "passthrough") {
        hashingStream = crypto.createHash(options.algorithm);
      } else {
        hashingStream = new PassThrough();
      }
      if (typeof hashingStream.write === "undefined") {
        hashingStream.write = hashingStream.update;
        hashingStream.end = hashingStream.update;
      }
      var hasher = typeHasher(options, hashingStream);
      hasher.dispatch(object);
      if (!hashingStream.update) {
        hashingStream.end("");
      }
      if (hashingStream.digest) {
        return hashingStream.digest(options.encoding === "buffer" ? void 0 : options.encoding);
      }
      var buf = hashingStream.read();
      if (options.encoding === "buffer") {
        return buf;
      }
      return buf.toString(options.encoding);
    }
    exports2.writeToStream = function(object, options, stream) {
      if (typeof stream === "undefined") {
        stream = options;
        options = {};
      }
      options = applyDefaults(object, options);
      return typeHasher(options, stream).dispatch(object);
    };
    function typeHasher(options, writeTo, context) {
      context = context || [];
      var write = function(str) {
        if (writeTo.update) {
          return writeTo.update(str, "utf8");
        } else {
          return writeTo.write(str, "utf8");
        }
      };
      return {
        dispatch: function(value) {
          if (options.replacer) {
            value = options.replacer(value);
          }
          var type = typeof value;
          if (value === null) {
            type = "null";
          }
          return this["_" + type](value);
        },
        _object: function(object) {
          var pattern = /\[object (.*)\]/i;
          var objString = Object.prototype.toString.call(object);
          var objType = pattern.exec(objString);
          if (!objType) {
            objType = "unknown:[" + objString + "]";
          } else {
            objType = objType[1];
          }
          objType = objType.toLowerCase();
          var objectNumber = null;
          if ((objectNumber = context.indexOf(object)) >= 0) {
            return this.dispatch("[CIRCULAR:" + objectNumber + "]");
          } else {
            context.push(object);
          }
          if (typeof Buffer !== "undefined" && Buffer.isBuffer && Buffer.isBuffer(object)) {
            write("buffer:");
            return write(object);
          }
          if (objType !== "object" && objType !== "function" && objType !== "asyncfunction") {
            if (this["_" + objType]) {
              this["_" + objType](object);
            } else if (options.ignoreUnknown) {
              return write("[" + objType + "]");
            } else {
              throw new Error('Unknown object type "' + objType + '"');
            }
          } else {
            var keys = Object.keys(object);
            if (options.unorderedObjects) {
              keys = keys.sort();
            }
            if (options.respectType !== false && !isNativeFunction(object)) {
              keys.splice(0, 0, "prototype", "__proto__", "constructor");
            }
            if (options.excludeKeys) {
              keys = keys.filter(function(key) {
                return !options.excludeKeys(key);
              });
            }
            write("object:" + keys.length + ":");
            var self2 = this;
            return keys.forEach(function(key) {
              self2.dispatch(key);
              write(":");
              if (!options.excludeValues) {
                self2.dispatch(object[key]);
              }
              write(",");
            });
          }
        },
        _array: function(arr, unordered) {
          unordered = typeof unordered !== "undefined" ? unordered : options.unorderedArrays !== false;
          var self2 = this;
          write("array:" + arr.length + ":");
          if (!unordered || arr.length <= 1) {
            return arr.forEach(function(entry) {
              return self2.dispatch(entry);
            });
          }
          var contextAdditions = [];
          var entries = arr.map(function(entry) {
            var strm = new PassThrough();
            var localContext = context.slice();
            var hasher = typeHasher(options, strm, localContext);
            hasher.dispatch(entry);
            contextAdditions = contextAdditions.concat(localContext.slice(context.length));
            return strm.read().toString();
          });
          context = context.concat(contextAdditions);
          entries.sort();
          return this._array(entries, false);
        },
        _date: function(date) {
          return write("date:" + date.toJSON());
        },
        _symbol: function(sym) {
          return write("symbol:" + sym.toString());
        },
        _error: function(err) {
          return write("error:" + err.toString());
        },
        _boolean: function(bool) {
          return write("bool:" + bool.toString());
        },
        _string: function(string) {
          write("string:" + string.length + ":");
          write(string.toString());
        },
        _function: function(fn) {
          write("fn:");
          if (isNativeFunction(fn)) {
            this.dispatch("[native]");
          } else {
            this.dispatch(fn.toString());
          }
          if (options.respectFunctionNames !== false) {
            this.dispatch("function-name:" + String(fn.name));
          }
          if (options.respectFunctionProperties) {
            this._object(fn);
          }
        },
        _number: function(number) {
          return write("number:" + number.toString());
        },
        _xml: function(xml) {
          return write("xml:" + xml.toString());
        },
        _null: function() {
          return write("Null");
        },
        _undefined: function() {
          return write("Undefined");
        },
        _regexp: function(regex) {
          return write("regex:" + regex.toString());
        },
        _uint8array: function(arr) {
          write("uint8array:");
          return this.dispatch(Array.prototype.slice.call(arr));
        },
        _uint8clampedarray: function(arr) {
          write("uint8clampedarray:");
          return this.dispatch(Array.prototype.slice.call(arr));
        },
        _int8array: function(arr) {
          write("int8array:");
          return this.dispatch(Array.prototype.slice.call(arr));
        },
        _uint16array: function(arr) {
          write("uint16array:");
          return this.dispatch(Array.prototype.slice.call(arr));
        },
        _int16array: function(arr) {
          write("int16array:");
          return this.dispatch(Array.prototype.slice.call(arr));
        },
        _uint32array: function(arr) {
          write("uint32array:");
          return this.dispatch(Array.prototype.slice.call(arr));
        },
        _int32array: function(arr) {
          write("int32array:");
          return this.dispatch(Array.prototype.slice.call(arr));
        },
        _float32array: function(arr) {
          write("float32array:");
          return this.dispatch(Array.prototype.slice.call(arr));
        },
        _float64array: function(arr) {
          write("float64array:");
          return this.dispatch(Array.prototype.slice.call(arr));
        },
        _arraybuffer: function(arr) {
          write("arraybuffer:");
          return this.dispatch(new Uint8Array(arr));
        },
        _url: function(url) {
          return write("url:" + url.toString(), "utf8");
        },
        _map: function(map) {
          write("map:");
          var arr = Array.from(map);
          return this._array(arr, options.unorderedSets !== false);
        },
        _set: function(set) {
          write("set:");
          var arr = Array.from(set);
          return this._array(arr, options.unorderedSets !== false);
        },
        _file: function(file) {
          write("file:");
          return this.dispatch([file.name, file.size, file.type, file.lastModfied]);
        },
        _blob: function() {
          if (options.ignoreUnknown) {
            return write("[blob]");
          }
          throw Error('Hashing Blob objects is currently not supported\n(see https://github.com/puleos/object-hash/issues/26)\nUse "options.replacer" or "options.ignoreUnknown"\n');
        },
        _domwindow: function() {
          return write("domwindow");
        },
        _bigint: function(number) {
          return write("bigint:" + number.toString());
        },
        /* Node.js standard native objects */
        _process: function() {
          return write("process");
        },
        _timer: function() {
          return write("timer");
        },
        _pipe: function() {
          return write("pipe");
        },
        _tcp: function() {
          return write("tcp");
        },
        _udp: function() {
          return write("udp");
        },
        _tty: function() {
          return write("tty");
        },
        _statwatcher: function() {
          return write("statwatcher");
        },
        _securecontext: function() {
          return write("securecontext");
        },
        _connection: function() {
          return write("connection");
        },
        _zlib: function() {
          return write("zlib");
        },
        _context: function() {
          return write("context");
        },
        _nodescript: function() {
          return write("nodescript");
        },
        _httpparser: function() {
          return write("httpparser");
        },
        _dataview: function() {
          return write("dataview");
        },
        _signal: function() {
          return write("signal");
        },
        _fsevent: function() {
          return write("fsevent");
        },
        _tlswrap: function() {
          return write("tlswrap");
        }
      };
    }
    function PassThrough() {
      return {
        buf: "",
        write: function(b) {
          this.buf += b;
        },
        end: function(b) {
          this.buf += b;
        },
        read: function() {
          return this.buf;
        }
      };
    }
  }
});

// node_modules/moment/moment.js
var require_moment = __commonJS({
  "node_modules/moment/moment.js"(exports2, module2) {
    (function(global2, factory) {
      typeof exports2 === "object" && typeof module2 !== "undefined" ? module2.exports = factory() : typeof define === "function" && define.amd ? define(factory) : global2.moment = factory();
    })(exports2, (function() {
      "use strict";
      var hookCallback;
      function hooks() {
        return hookCallback.apply(null, arguments);
      }
      function setHookCallback(callback) {
        hookCallback = callback;
      }
      function isArray(input) {
        return input instanceof Array || Object.prototype.toString.call(input) === "[object Array]";
      }
      function isObject(input) {
        return input != null && Object.prototype.toString.call(input) === "[object Object]";
      }
      function hasOwnProp(a, b) {
        return Object.prototype.hasOwnProperty.call(a, b);
      }
      function isObjectEmpty(obj) {
        if (Object.getOwnPropertyNames) {
          return Object.getOwnPropertyNames(obj).length === 0;
        } else {
          var k;
          for (k in obj) {
            if (hasOwnProp(obj, k)) {
              return false;
            }
          }
          return true;
        }
      }
      function isUndefined(input) {
        return input === void 0;
      }
      function isNumber(input) {
        return typeof input === "number" || Object.prototype.toString.call(input) === "[object Number]";
      }
      function isDate(input) {
        return input instanceof Date || Object.prototype.toString.call(input) === "[object Date]";
      }
      function map(arr, fn) {
        var res = [], i, arrLen = arr.length;
        for (i = 0; i < arrLen; ++i) {
          res.push(fn(arr[i], i));
        }
        return res;
      }
      function extend(a, b) {
        for (var i in b) {
          if (hasOwnProp(b, i)) {
            a[i] = b[i];
          }
        }
        if (hasOwnProp(b, "toString")) {
          a.toString = b.toString;
        }
        if (hasOwnProp(b, "valueOf")) {
          a.valueOf = b.valueOf;
        }
        return a;
      }
      function createUTC(input, format2, locale2, strict) {
        return createLocalOrUTC(input, format2, locale2, strict, true).utc();
      }
      function defaultParsingFlags() {
        return {
          empty: false,
          unusedTokens: [],
          unusedInput: [],
          overflow: -2,
          charsLeftOver: 0,
          nullInput: false,
          invalidEra: null,
          invalidMonth: null,
          invalidOffset: null,
          invalidFormat: false,
          userInvalidated: false,
          iso: false,
          parsedDateParts: [],
          era: null,
          meridiem: null,
          rfc2822: false,
          weekdayMismatch: false
        };
      }
      function getParsingFlags(m) {
        if (m._pf == null) {
          m._pf = defaultParsingFlags();
        }
        return m._pf;
      }
      var some;
      if (Array.prototype.some) {
        some = Array.prototype.some;
      } else {
        some = function(fun) {
          var t = Object(this), len = t.length >>> 0, i;
          for (i = 0; i < len; i++) {
            if (i in t && fun.call(this, t[i], i, t)) {
              return true;
            }
          }
          return false;
        };
      }
      function isValid$2(m) {
        var flags = null, parsedParts = false, isNowValid = m._d && !isNaN(m._d.getTime());
        if (isNowValid) {
          flags = getParsingFlags(m);
          parsedParts = some.call(flags.parsedDateParts, function(i) {
            return i != null;
          });
          isNowValid = flags.overflow < 0 && !flags.empty && !flags.invalidEra && !flags.invalidMonth && !flags.invalidOffset && !flags.invalidWeekday && !flags.weekdayMismatch && !flags.nullInput && !flags.invalidFormat && !flags.userInvalidated && (!flags.meridiem || flags.meridiem && parsedParts);
          if (m._strict) {
            isNowValid = isNowValid && flags.charsLeftOver === 0 && flags.unusedTokens.length === 0 && flags.bigHour === void 0;
          }
        }
        if (Object.isFrozen == null || !Object.isFrozen(m)) {
          m._isValid = isNowValid;
        } else {
          return isNowValid;
        }
        return m._isValid;
      }
      function createInvalid$1(flags) {
        var m = createUTC(NaN);
        if (flags != null) {
          extend(getParsingFlags(m), flags);
        } else {
          getParsingFlags(m).userInvalidated = true;
        }
        return m;
      }
      var momentProperties = hooks.momentProperties = [], updateInProgress = false;
      function copyConfig(to2, from2) {
        var i, prop, val, momentPropertiesLen = momentProperties.length;
        if (!isUndefined(from2._isAMomentObject)) {
          to2._isAMomentObject = from2._isAMomentObject;
        }
        if (!isUndefined(from2._i)) {
          to2._i = from2._i;
        }
        if (!isUndefined(from2._f)) {
          to2._f = from2._f;
        }
        if (!isUndefined(from2._l)) {
          to2._l = from2._l;
        }
        if (!isUndefined(from2._strict)) {
          to2._strict = from2._strict;
        }
        if (!isUndefined(from2._tzm)) {
          to2._tzm = from2._tzm;
        }
        if (!isUndefined(from2._isUTC)) {
          to2._isUTC = from2._isUTC;
        }
        if (!isUndefined(from2._offset)) {
          to2._offset = from2._offset;
        }
        if (!isUndefined(from2._pf)) {
          to2._pf = getParsingFlags(from2);
        }
        if (!isUndefined(from2._locale)) {
          to2._locale = from2._locale;
        }
        if (momentPropertiesLen > 0) {
          for (i = 0; i < momentPropertiesLen; i++) {
            prop = momentProperties[i];
            val = from2[prop];
            if (!isUndefined(val)) {
              to2[prop] = val;
            }
          }
        }
        return to2;
      }
      function Moment(config) {
        copyConfig(this, config);
        this._d = new Date(config._d != null ? config._d.getTime() : NaN);
        if (!this.isValid()) {
          this._d = /* @__PURE__ */ new Date(NaN);
        }
        if (updateInProgress === false) {
          updateInProgress = true;
          hooks.updateOffset(this);
          updateInProgress = false;
        }
      }
      function isMoment(obj) {
        return obj instanceof Moment || obj != null && obj._isAMomentObject != null;
      }
      function warn(msg) {
        if (hooks.suppressDeprecationWarnings === false && typeof console !== "undefined" && console.warn) {
          console.warn("Deprecation warning: " + msg);
        }
      }
      function deprecate(msg, fn) {
        var firstTime = true;
        return extend(function() {
          if (hooks.deprecationHandler != null) {
            hooks.deprecationHandler(null, msg);
          }
          if (firstTime) {
            var args = [], arg, i, key, argLen = arguments.length;
            for (i = 0; i < argLen; i++) {
              arg = "";
              if (typeof arguments[i] === "object") {
                arg += "\n[" + i + "] ";
                for (key in arguments[0]) {
                  if (hasOwnProp(arguments[0], key)) {
                    arg += key + ": " + arguments[0][key] + ", ";
                  }
                }
                arg = arg.slice(0, -2);
              } else {
                arg = arguments[i];
              }
              args.push(arg);
            }
            warn(
              msg + "\nArguments: " + Array.prototype.slice.call(args).join("") + "\n" + new Error().stack
            );
            firstTime = false;
          }
          return fn.apply(this, arguments);
        }, fn);
      }
      var deprecations = {};
      function deprecateSimple(name, msg) {
        if (hooks.deprecationHandler != null) {
          hooks.deprecationHandler(name, msg);
        }
        if (!deprecations[name]) {
          warn(msg + "\n" + new Error().stack);
          deprecations[name] = true;
        }
      }
      hooks.suppressDeprecationWarnings = false;
      hooks.deprecationHandler = null;
      function isFunction(input) {
        return typeof Function !== "undefined" && input instanceof Function || Object.prototype.toString.call(input) === "[object Function]";
      }
      var aliases = {
        D: "date",
        dates: "date",
        date: "date",
        d: "day",
        days: "day",
        day: "day",
        e: "weekday",
        weekdays: "weekday",
        weekday: "weekday",
        E: "isoWeekday",
        isoweekdays: "isoWeekday",
        isoweekday: "isoWeekday",
        DDD: "dayOfYear",
        dayofyears: "dayOfYear",
        dayofyear: "dayOfYear",
        h: "hour",
        hours: "hour",
        hour: "hour",
        ms: "millisecond",
        milliseconds: "millisecond",
        millisecond: "millisecond",
        m: "minute",
        minutes: "minute",
        minute: "minute",
        M: "month",
        months: "month",
        month: "month",
        Q: "quarter",
        quarters: "quarter",
        quarter: "quarter",
        s: "second",
        seconds: "second",
        second: "second",
        gg: "weekYear",
        weekyears: "weekYear",
        weekyear: "weekYear",
        GG: "isoWeekYear",
        isoweekyears: "isoWeekYear",
        isoweekyear: "isoWeekYear",
        w: "week",
        weeks: "week",
        week: "week",
        W: "isoWeek",
        isoweeks: "isoWeek",
        isoweek: "isoWeek",
        y: "year",
        years: "year",
        year: "year"
      };
      function normalizeUnits(units) {
        return typeof units === "string" ? aliases[units] || aliases[units.toLowerCase()] : void 0;
      }
      function normalizeObjectUnits(inputObject) {
        var normalizedInput = {}, normalizedProp, prop;
        for (prop in inputObject) {
          if (hasOwnProp(inputObject, prop)) {
            normalizedProp = normalizeUnits(prop);
            if (normalizedProp) {
              normalizedInput[normalizedProp] = inputObject[prop];
            }
          }
        }
        return normalizedInput;
      }
      var priorities = {
        date: 9,
        day: 11,
        weekday: 11,
        isoWeekday: 11,
        dayOfYear: 4,
        hour: 13,
        millisecond: 16,
        minute: 14,
        month: 8,
        quarter: 7,
        second: 15,
        weekYear: 1,
        isoWeekYear: 1,
        week: 5,
        isoWeek: 5,
        year: 1
      };
      function getPrioritizedUnits(unitsObj) {
        var units = [], u;
        for (u in unitsObj) {
          if (hasOwnProp(unitsObj, u)) {
            units.push({ unit: u, priority: priorities[u] });
          }
        }
        units.sort(function(a, b) {
          return a.priority - b.priority;
        });
        return units;
      }
      function zeroFill(number, targetLength, forceSign) {
        var absNumber = "" + Math.abs(number), zerosToFill = targetLength - absNumber.length, sign2 = number >= 0;
        return (sign2 ? forceSign ? "+" : "" : "-") + Math.pow(10, Math.max(0, zerosToFill)).toString().substr(1) + absNumber;
      }
      var formattingTokens = /(\[[^\[]*\])|(\\e)|(\\)?(eHHmm|[Hh]mm(ss)?|Mo|MM?M?M?|Do|DDDo|DD?D?D?|ddd?d?|do?|w[o|w]?|W[o|W]?|Qo?|N{1,5}|YYYYYY|YYYYY|YYYY|YY|y{2,4}|yo?|gg(ggg?)?|GG(GGG?)?|e|E|a|A|hh?|HH?|kk?|mm?|ss?|S{1,9}|x|X|zz?|ZZ?|.)/g, localFormattingTokens = /(\[[^\[]*\])|(\\)?(LTS|LT|LL?L?L?|l{1,4})/g, formatFunctions = {}, formatTokenFunctions = {};
      function addFormatToken(token2, padded, ordinal2, callback) {
        var func = callback;
        if (typeof callback === "string") {
          func = function() {
            return this[callback]();
          };
        }
        if (token2) {
          formatTokenFunctions[token2] = func;
        }
        if (padded) {
          formatTokenFunctions[padded[0]] = function() {
            return zeroFill(func.apply(this, arguments), padded[1], padded[2]);
          };
        }
        if (ordinal2) {
          formatTokenFunctions[ordinal2] = function() {
            return this.localeData().ordinal(
              func.apply(this, arguments),
              token2
            );
          };
        }
      }
      function removeFormattingTokens(input) {
        if (input.match(/\[[\s\S]/)) {
          return input.replace(/^\[|\]$/g, "");
        }
        return input.replace(/\\/g, "");
      }
      function makeFormatFunction(format2) {
        var array = format2.match(formattingTokens), i, length;
        for (i = 0, length = array.length; i < length; i++) {
          if (formatTokenFunctions[array[i]]) {
            array[i] = formatTokenFunctions[array[i]];
          } else {
            array[i] = removeFormattingTokens(array[i]);
          }
        }
        return function(mom) {
          var output = "", i2;
          for (i2 = 0; i2 < length; i2++) {
            output += isFunction(array[i2]) ? array[i2].call(mom, format2) : array[i2];
          }
          return output;
        };
      }
      function formatMoment(m, format2) {
        if (!m.isValid()) {
          return m.localeData().invalidDate();
        }
        format2 = expandFormat(format2, m.localeData());
        var cacheKey = "$" + format2;
        if (!hasOwnProp(formatFunctions, cacheKey)) {
          formatFunctions[cacheKey] = makeFormatFunction(format2);
        }
        return formatFunctions[cacheKey](m);
      }
      function expandFormat(format2, locale2) {
        var i = 5;
        function replaceLongDateFormatTokens(input) {
          return locale2.longDateFormat(input) || input;
        }
        localFormattingTokens.lastIndex = 0;
        while (i >= 0 && localFormattingTokens.test(format2)) {
          format2 = format2.replace(
            localFormattingTokens,
            replaceLongDateFormatTokens
          );
          localFormattingTokens.lastIndex = 0;
          i -= 1;
        }
        return format2;
      }
      var match1 = /\d/, match2 = /\d\d/, match3 = /\d{3}/, match4 = /\d{4}/, match6 = /[+-]?\d{6}/, match1to2 = /\d\d?/, match3to4 = /\d\d\d\d?/, match5to6 = /\d\d\d\d\d\d?/, match1to3 = /\d{1,3}/, match1to4 = /\d{1,4}/, match1to6 = /[+-]?\d{1,6}/, matchUnsigned = /\d+/, matchSigned = /[+-]?\d+/, matchOffset = /Z|[+-]\d\d:?\d\d/gi, matchShortOffset = /Z|[+-]\d\d(?::?\d\d)?/gi, matchTimestamp = /[+-]?\d+(\.\d{1,3})?/, matchWord = /[0-9]{0,256}['a-z\u00A0-\u05FF\u0700-\uD7FF\uF900-\uFDCF\uFDF0-\uFF07\uFF10-\uFFEF]{1,256}|[\u0600-\u06FF\/]{1,256}(\s*?[\u0600-\u06FF]{1,256}){1,2}/i, match1to2NoLeadingZero = /^[1-9]\d?/, match1to2HasZero = /^([1-9]\d|\d)/, regexes;
      regexes = {};
      function addRegexToken(token2, regex, strictRegex) {
        regexes[token2] = isFunction(regex) ? regex : function(isStrict, localeData2) {
          return isStrict && strictRegex ? strictRegex : regex;
        };
      }
      function getParseRegexForToken(token2, config) {
        if (!hasOwnProp(regexes, token2)) {
          return new RegExp(unescapeFormat(token2));
        }
        return regexes[token2](config._strict, config._locale);
      }
      function unescapeFormat(s) {
        return regexEscape(
          s.replace("\\", "").replace(
            /\\(\[)|\\(\])|\[([^\]\[]*)\]|\\(.)/g,
            function(matched, p1, p2, p3, p4) {
              return p1 || p2 || p3 || p4;
            }
          )
        );
      }
      function regexEscape(s) {
        return s.replace(/[-\/\\^$*+?.()|[\]{}]/g, "\\$&");
      }
      function absFloor(number) {
        if (number < 0) {
          return Math.ceil(number) || 0;
        } else {
          return Math.floor(number);
        }
      }
      function toInt(argumentForCoercion) {
        var coercedNumber = +argumentForCoercion, value = 0;
        if (coercedNumber !== 0 && isFinite(coercedNumber)) {
          value = absFloor(coercedNumber);
        }
        return value;
      }
      var tokens = {};
      function addParseToken(token2, callback) {
        var i, func = callback, tokenLen;
        if (typeof token2 === "string") {
          token2 = [token2];
        }
        if (isNumber(callback)) {
          func = function(input, array) {
            array[callback] = toInt(input);
          };
        }
        tokenLen = token2.length;
        for (i = 0; i < tokenLen; i++) {
          tokens[token2[i]] = func;
        }
      }
      function addWeekParseToken(token2, callback) {
        addParseToken(token2, function(input, array, config, token3) {
          config._w = config._w || {};
          callback(input, config._w, config, token3);
        });
      }
      function addTimeToArrayFromToken(token2, input, config) {
        if (input != null && hasOwnProp(tokens, token2)) {
          tokens[token2](input, config._a, config, token2);
        }
      }
      function isLeapYear(year) {
        return year % 4 === 0 && year % 100 !== 0 || year % 400 === 0;
      }
      var YEAR = 0, MONTH = 1, DATE = 2, HOUR = 3, MINUTE = 4, SECOND = 5, MILLISECOND = 6, WEEK = 7, WEEKDAY = 8;
      addFormatToken("Y", 0, 0, function() {
        var y = this.year();
        return y <= 9999 ? zeroFill(y, 4) : "+" + y;
      });
      addFormatToken(0, ["YY", 2], 0, function() {
        return this.year() % 100;
      });
      addFormatToken(0, ["YYYY", 4], 0, "year");
      addFormatToken(0, ["YYYYY", 5], 0, "year");
      addFormatToken(0, ["YYYYYY", 6, true], 0, "year");
      addRegexToken("Y", matchSigned);
      addRegexToken("YY", match1to2, match2);
      addRegexToken("YYYY", match1to4, match4);
      addRegexToken("YYYYY", match1to6, match6);
      addRegexToken("YYYYYY", match1to6, match6);
      addParseToken(["YYYYY", "YYYYYY"], YEAR);
      addParseToken("YYYY", function(input, array) {
        array[YEAR] = input.length === 2 ? hooks.parseTwoDigitYear(input) : toInt(input);
      });
      addParseToken("YY", function(input, array) {
        array[YEAR] = hooks.parseTwoDigitYear(input);
      });
      addParseToken("Y", function(input, array) {
        array[YEAR] = parseInt(input, 10);
      });
      function daysInYear(year) {
        return isLeapYear(year) ? 366 : 365;
      }
      hooks.parseTwoDigitYear = function(input) {
        return toInt(input) + (toInt(input) > 68 ? 1900 : 2e3);
      };
      var getSetYear = makeGetSet("FullYear", true);
      function getIsLeapYear() {
        return isLeapYear(this.year());
      }
      function makeGetSet(unit, keepTime) {
        return function(value) {
          if (value != null) {
            set$1(this, unit, value);
            hooks.updateOffset(this, keepTime);
            return this;
          } else {
            return get$2(this, unit);
          }
        };
      }
      function get$2(mom, unit) {
        if (!mom.isValid()) {
          return NaN;
        }
        var d = mom._d, isUTC = mom._isUTC;
        switch (unit) {
          case "Milliseconds":
            return isUTC ? d.getUTCMilliseconds() : d.getMilliseconds();
          case "Seconds":
            return isUTC ? d.getUTCSeconds() : d.getSeconds();
          case "Minutes":
            return isUTC ? d.getUTCMinutes() : d.getMinutes();
          case "Hours":
            return isUTC ? d.getUTCHours() : d.getHours();
          case "Date":
            return isUTC ? d.getUTCDate() : d.getDate();
          case "Day":
            return isUTC ? d.getUTCDay() : d.getDay();
          case "Month":
            return isUTC ? d.getUTCMonth() : d.getMonth();
          case "FullYear":
            return isUTC ? d.getUTCFullYear() : d.getFullYear();
          default:
            return NaN;
        }
      }
      function set$1(mom, unit, value) {
        var d, isUTC, year, month, date;
        if (!mom.isValid() || isNaN(value)) {
          return;
        }
        d = mom._d;
        isUTC = mom._isUTC;
        switch (unit) {
          case "Milliseconds":
            return void (isUTC ? d.setUTCMilliseconds(value) : d.setMilliseconds(value));
          case "Seconds":
            return void (isUTC ? d.setUTCSeconds(value) : d.setSeconds(value));
          case "Minutes":
            return void (isUTC ? d.setUTCMinutes(value) : d.setMinutes(value));
          case "Hours":
            return void (isUTC ? d.setUTCHours(value) : d.setHours(value));
          case "Date":
            return void (isUTC ? d.setUTCDate(value) : d.setDate(value));
          // case 'Day': // Not real
          //    return void (isUTC ? d.setUTCDay(value) : d.setDay(value));
          // case 'Month': // Not used because we need to pass two variables
          //     return void (isUTC ? d.setUTCMonth(value) : d.setMonth(value));
          case "FullYear":
            break;
          // See below ...
          default:
            return;
        }
        year = value;
        month = mom.month();
        date = mom.date();
        date = date === 29 && month === 1 && !isLeapYear(year) ? 28 : date;
        void (isUTC ? d.setUTCFullYear(year, month, date) : d.setFullYear(year, month, date));
      }
      function stringGet(units) {
        units = normalizeUnits(units);
        if (isFunction(this[units])) {
          return this[units]();
        }
        return this;
      }
      function stringSet(units, value) {
        if (typeof units === "object") {
          units = normalizeObjectUnits(units);
          var prioritized = getPrioritizedUnits(units), i, prioritizedLen = prioritized.length;
          for (i = 0; i < prioritizedLen; i++) {
            this[prioritized[i].unit](units[prioritized[i].unit]);
          }
        } else {
          units = normalizeUnits(units);
          if (isFunction(this[units])) {
            return this[units](value);
          }
        }
        return this;
      }
      function mod$1(n, x) {
        return (n % x + x) % x;
      }
      var indexOf;
      if (Array.prototype.indexOf) {
        indexOf = Array.prototype.indexOf;
      } else {
        indexOf = function(o) {
          var i;
          for (i = 0; i < this.length; ++i) {
            if (this[i] === o) {
              return i;
            }
          }
          return -1;
        };
      }
      function daysInMonth(year, month) {
        if (isNaN(year) || isNaN(month)) {
          return NaN;
        }
        var modMonth = mod$1(month, 12);
        year += (month - modMonth) / 12;
        return modMonth === 1 ? isLeapYear(year) ? 29 : 28 : 31 - modMonth % 7 % 2;
      }
      addFormatToken("M", ["MM", 2], "Mo", function() {
        return this.month() + 1;
      });
      addFormatToken("MMM", 0, 0, function(format2) {
        return this.localeData().monthsShort(this, format2);
      });
      addFormatToken("MMMM", 0, 0, function(format2) {
        return this.localeData().months(this, format2);
      });
      addRegexToken("M", match1to2, match1to2NoLeadingZero);
      addRegexToken("MM", match1to2, match2);
      addRegexToken("MMM", function(isStrict, locale2) {
        return locale2.monthsShortRegex(isStrict);
      });
      addRegexToken("MMMM", function(isStrict, locale2) {
        return locale2.monthsRegex(isStrict);
      });
      addParseToken(["M", "MM"], function(input, array) {
        array[MONTH] = toInt(input) - 1;
      });
      addParseToken(["MMM", "MMMM"], function(input, array, config, token2) {
        var month = config._locale.monthsParse(input, token2, config._strict);
        if (month != null) {
          array[MONTH] = month;
        } else {
          getParsingFlags(config).invalidMonth = input;
        }
      });
      var defaultLocaleMonths = "January_February_March_April_May_June_July_August_September_October_November_December".split(
        "_"
      ), defaultLocaleMonthsShort = "Jan_Feb_Mar_Apr_May_Jun_Jul_Aug_Sep_Oct_Nov_Dec".split("_"), MONTHS_IN_FORMAT = /D[oD]?(\[[^\[\]]*\]|\s)+MMMM?/, defaultMonthsShortRegex = matchWord, defaultMonthsRegex = matchWord, monthsParseProperties = [
        "monthsParse",
        "longMonthsParse",
        "shortMonthsParse",
        "monthsRegex",
        "monthsShortRegex",
        "monthsStrictRegex",
        "monthsShortStrictRegex"
      ];
      function clearMonthsParseCache(locale2, config) {
        var i, prop;
        for (i = 0; i < monthsParseProperties.length; i++) {
          prop = monthsParseProperties[i];
          if (!hasOwnProp(config, prop)) {
            delete locale2["_" + prop];
          }
        }
      }
      function localeMonths(m, format2) {
        if (!m) {
          return isArray(this._months) ? this._months : this._months["standalone"];
        }
        return isArray(this._months) ? this._months[m.month()] : this._months[(this._months.isFormat || MONTHS_IN_FORMAT).test(format2) ? "format" : "standalone"][m.month()];
      }
      function localeMonthsShort(m, format2) {
        if (!m) {
          return isArray(this._monthsShort) ? this._monthsShort : this._monthsShort["standalone"];
        }
        return isArray(this._monthsShort) ? this._monthsShort[m.month()] : this._monthsShort[MONTHS_IN_FORMAT.test(format2) ? "format" : "standalone"][m.month()];
      }
      function handleStrictParse$1(monthName, format2, strict) {
        var i, ii, mom, llc = monthName.toLocaleLowerCase();
        if (!this._monthsParse) {
          this._monthsParse = [];
          this._longMonthsParse = [];
          this._shortMonthsParse = [];
          for (i = 0; i < 12; ++i) {
            mom = createUTC([2e3, i]);
            this._shortMonthsParse[i] = this.monthsShort(
              mom,
              ""
            ).toLocaleLowerCase();
            this._longMonthsParse[i] = this.months(mom, "").toLocaleLowerCase();
          }
        }
        if (strict) {
          if (format2 === "MMM") {
            ii = indexOf.call(this._shortMonthsParse, llc);
            return ii !== -1 ? ii : null;
          } else {
            ii = indexOf.call(this._longMonthsParse, llc);
            return ii !== -1 ? ii : null;
          }
        } else {
          if (format2 === "MMM") {
            ii = indexOf.call(this._shortMonthsParse, llc);
            if (ii !== -1) {
              return ii;
            }
            ii = indexOf.call(this._longMonthsParse, llc);
            return ii !== -1 ? ii : null;
          } else {
            ii = indexOf.call(this._longMonthsParse, llc);
            if (ii !== -1) {
              return ii;
            }
            ii = indexOf.call(this._shortMonthsParse, llc);
            return ii !== -1 ? ii : null;
          }
        }
      }
      function localeMonthsParse(monthName, format2, strict) {
        var i, mom, regex;
        if (this._monthsParseExact) {
          return handleStrictParse$1.call(this, monthName, format2, strict);
        }
        if (!this._monthsParse) {
          this._monthsParse = [];
          this._longMonthsParse = [];
          this._shortMonthsParse = [];
        }
        for (i = 0; i < 12; i++) {
          mom = createUTC([2e3, i]);
          if (strict && !this._longMonthsParse[i]) {
            this._longMonthsParse[i] = new RegExp(
              "^" + this.months(mom, "").replace(".", "") + "$",
              "i"
            );
            this._shortMonthsParse[i] = new RegExp(
              "^" + this.monthsShort(mom, "").replace(".", "") + "$",
              "i"
            );
          }
          if (!strict && !this._monthsParse[i]) {
            regex = "^" + this.months(mom, "") + "|^" + this.monthsShort(mom, "");
            this._monthsParse[i] = new RegExp(regex.replace(".", ""), "i");
          }
          if (strict && format2 === "MMMM" && this._longMonthsParse[i].test(monthName)) {
            return i;
          } else if (strict && format2 === "MMM" && this._shortMonthsParse[i].test(monthName)) {
            return i;
          } else if (!strict && this._monthsParse[i].test(monthName)) {
            return i;
          }
        }
      }
      function setMonth(mom, value) {
        if (!mom.isValid()) {
          return mom;
        }
        if (typeof value === "string") {
          if (/^\d+$/.test(value)) {
            value = toInt(value);
          } else {
            value = mom.localeData().monthsParse(value);
            if (!isNumber(value)) {
              return mom;
            }
          }
        }
        var month = value, date = mom.date();
        date = date < 29 ? date : Math.min(date, daysInMonth(mom.year(), month));
        void (mom._isUTC ? mom._d.setUTCMonth(month, date) : mom._d.setMonth(month, date));
        return mom;
      }
      function getSetMonth(value) {
        if (value != null) {
          setMonth(this, value);
          hooks.updateOffset(this, true);
          return this;
        } else {
          return get$2(this, "Month");
        }
      }
      function getDaysInMonth() {
        return daysInMonth(this.year(), this.month());
      }
      function monthsShortRegex(isStrict) {
        if (this._monthsParseExact) {
          if (!hasOwnProp(this, "_monthsRegex")) {
            computeMonthsParse.call(this);
          }
          if (isStrict) {
            return this._monthsShortStrictRegex;
          } else {
            return this._monthsShortRegex;
          }
        } else {
          if (!hasOwnProp(this, "_monthsShortRegex")) {
            this._monthsShortRegex = defaultMonthsShortRegex;
          }
          return this._monthsShortStrictRegex && isStrict ? this._monthsShortStrictRegex : this._monthsShortRegex;
        }
      }
      function monthsRegex(isStrict) {
        if (this._monthsParseExact) {
          if (!hasOwnProp(this, "_monthsRegex")) {
            computeMonthsParse.call(this);
          }
          if (isStrict) {
            return this._monthsStrictRegex;
          } else {
            return this._monthsRegex;
          }
        } else {
          if (!hasOwnProp(this, "_monthsRegex")) {
            this._monthsRegex = defaultMonthsRegex;
          }
          return this._monthsStrictRegex && isStrict ? this._monthsStrictRegex : this._monthsRegex;
        }
      }
      function computeMonthsParse() {
        function cmpLenRev(a, b) {
          return b.length - a.length;
        }
        var shortPieces = [], longPieces = [], mixedPieces = [], i, mom, shortP, longP;
        for (i = 0; i < 12; i++) {
          mom = createUTC([2e3, i]);
          shortP = regexEscape(this.monthsShort(mom, ""));
          longP = regexEscape(this.months(mom, ""));
          shortPieces.push(shortP);
          longPieces.push(longP);
          mixedPieces.push(longP);
          mixedPieces.push(shortP);
        }
        shortPieces.sort(cmpLenRev);
        longPieces.sort(cmpLenRev);
        mixedPieces.sort(cmpLenRev);
        this._monthsRegex = new RegExp("^(" + mixedPieces.join("|") + ")", "i");
        this._monthsShortRegex = this._monthsRegex;
        this._monthsStrictRegex = new RegExp(
          "^(" + longPieces.join("|") + ")",
          "i"
        );
        this._monthsShortStrictRegex = new RegExp(
          "^(" + shortPieces.join("|") + ")",
          "i"
        );
      }
      addFormatToken("d", 0, "do", "day");
      addFormatToken("dd", 0, 0, function(format2) {
        return this.localeData().weekdaysMin(this, format2);
      });
      addFormatToken("ddd", 0, 0, function(format2) {
        return this.localeData().weekdaysShort(this, format2);
      });
      addFormatToken("dddd", 0, 0, function(format2) {
        return this.localeData().weekdays(this, format2);
      });
      addFormatToken("e", 0, 0, "weekday");
      addFormatToken("E", 0, 0, "isoWeekday");
      addFormatToken("eHHmm", 0, 0, function() {
        return "" + this.weekday() + zeroFill(this.hours(), 2) + zeroFill(this.minutes(), 2);
      });
      addRegexToken("d", match1to2);
      addRegexToken("e", match1to2);
      addRegexToken("E", match1to2);
      addRegexToken("eHHmm", match5to6);
      addRegexToken("dd", function(isStrict, locale2) {
        return locale2.weekdaysMinRegex(isStrict);
      });
      addRegexToken("ddd", function(isStrict, locale2) {
        return locale2.weekdaysShortRegex(isStrict);
      });
      addRegexToken("dddd", function(isStrict, locale2) {
        return locale2.weekdaysRegex(isStrict);
      });
      addWeekParseToken(["dd", "ddd", "dddd"], function(input, week, config, token2) {
        var weekday = config._locale.weekdaysParse(input, token2, config._strict);
        if (weekday != null) {
          week.d = weekday;
        } else {
          getParsingFlags(config).invalidWeekday = input;
        }
      });
      addWeekParseToken(["d", "e", "E"], function(input, week, config, token2) {
        week[token2] = toInt(input);
      });
      addWeekParseToken("eHHmm", function(input, week, config) {
        var weekdayEnd = input.length - 4;
        week.e = toInt(input.substr(0, weekdayEnd));
        config._a[HOUR] = toInt(input.substr(weekdayEnd, 2));
        config._a[MINUTE] = toInt(input.substr(weekdayEnd + 2));
      });
      function parseWeekday(input, locale2) {
        if (typeof input !== "string") {
          return input;
        }
        if (!isNaN(input)) {
          return parseInt(input, 10);
        }
        input = locale2.weekdaysParse(input);
        if (typeof input === "number") {
          return input;
        }
        return null;
      }
      function parseIsoWeekday(input, locale2) {
        if (typeof input === "string") {
          return locale2.weekdaysParse(input) % 7 || 7;
        }
        return isNaN(input) ? null : input;
      }
      function shiftWeekdays(ws, n) {
        return ws.slice(n, 7).concat(ws.slice(0, n));
      }
      var defaultLocaleWeekdays = "Sunday_Monday_Tuesday_Wednesday_Thursday_Friday_Saturday".split("_"), defaultLocaleWeekdaysShort = "Sun_Mon_Tue_Wed_Thu_Fri_Sat".split("_"), defaultLocaleWeekdaysMin = "Su_Mo_Tu_We_Th_Fr_Sa".split("_"), defaultWeekdaysRegex = matchWord, defaultWeekdaysShortRegex = matchWord, defaultWeekdaysMinRegex = matchWord, weekdaysParseProperties = [
        "weekdaysParse",
        "fullWeekdaysParse",
        "shortWeekdaysParse",
        "minWeekdaysParse",
        "weekdaysRegex",
        "weekdaysShortRegex",
        "weekdaysMinRegex",
        "weekdaysStrictRegex",
        "weekdaysShortStrictRegex",
        "weekdaysMinStrictRegex"
      ];
      function clearWeekdaysParseCache(locale2, config) {
        var i, prop;
        for (i = 0; i < weekdaysParseProperties.length; i++) {
          prop = weekdaysParseProperties[i];
          if (!hasOwnProp(config, prop)) {
            delete locale2["_" + prop];
          }
        }
      }
      function localeWeekdays(m, format2) {
        var weekdays = isArray(this._weekdays) ? this._weekdays : this._weekdays[m && m !== true && this._weekdays.isFormat.test(format2) ? "format" : "standalone"];
        return m === true ? shiftWeekdays(weekdays, this._week.dow) : m ? weekdays[m.day()] : weekdays;
      }
      function localeWeekdaysShort(m) {
        return m === true ? shiftWeekdays(this._weekdaysShort, this._week.dow) : m ? this._weekdaysShort[m.day()] : this._weekdaysShort;
      }
      function localeWeekdaysMin(m) {
        return m === true ? shiftWeekdays(this._weekdaysMin, this._week.dow) : m ? this._weekdaysMin[m.day()] : this._weekdaysMin;
      }
      function handleStrictParse(weekdayName, format2, strict) {
        var i, ii, mom, llc = weekdayName.toLocaleLowerCase();
        if (!this._weekdaysParse) {
          this._weekdaysParse = [];
          this._shortWeekdaysParse = [];
          this._minWeekdaysParse = [];
          for (i = 0; i < 7; ++i) {
            mom = createUTC([2e3, 1]).day(i);
            this._minWeekdaysParse[i] = this.weekdaysMin(
              mom,
              ""
            ).toLocaleLowerCase();
            this._shortWeekdaysParse[i] = this.weekdaysShort(
              mom,
              ""
            ).toLocaleLowerCase();
            this._weekdaysParse[i] = this.weekdays(mom, "").toLocaleLowerCase();
          }
        }
        if (strict) {
          if (format2 === "dddd") {
            ii = indexOf.call(this._weekdaysParse, llc);
            return ii !== -1 ? ii : null;
          } else if (format2 === "ddd") {
            ii = indexOf.call(this._shortWeekdaysParse, llc);
            return ii !== -1 ? ii : null;
          } else {
            ii = indexOf.call(this._minWeekdaysParse, llc);
            return ii !== -1 ? ii : null;
          }
        } else {
          if (format2 === "dddd") {
            ii = indexOf.call(this._weekdaysParse, llc);
            if (ii !== -1) {
              return ii;
            }
            ii = indexOf.call(this._shortWeekdaysParse, llc);
            if (ii !== -1) {
              return ii;
            }
            ii = indexOf.call(this._minWeekdaysParse, llc);
            return ii !== -1 ? ii : null;
          } else if (format2 === "ddd") {
            ii = indexOf.call(this._shortWeekdaysParse, llc);
            if (ii !== -1) {
              return ii;
            }
            ii = indexOf.call(this._weekdaysParse, llc);
            if (ii !== -1) {
              return ii;
            }
            ii = indexOf.call(this._minWeekdaysParse, llc);
            return ii !== -1 ? ii : null;
          } else {
            ii = indexOf.call(this._minWeekdaysParse, llc);
            if (ii !== -1) {
              return ii;
            }
            ii = indexOf.call(this._weekdaysParse, llc);
            if (ii !== -1) {
              return ii;
            }
            ii = indexOf.call(this._shortWeekdaysParse, llc);
            return ii !== -1 ? ii : null;
          }
        }
      }
      function localeWeekdaysParse(weekdayName, format2, strict) {
        var i, mom, regex;
        if (this._weekdaysParseExact) {
          return handleStrictParse.call(this, weekdayName, format2, strict);
        }
        if (!this._weekdaysParse) {
          this._weekdaysParse = [];
          this._minWeekdaysParse = [];
          this._shortWeekdaysParse = [];
          this._fullWeekdaysParse = [];
        }
        for (i = 0; i < 7; i++) {
          mom = createUTC([2e3, 1]).day(i);
          if (strict && !this._fullWeekdaysParse[i]) {
            this._fullWeekdaysParse[i] = new RegExp(
              "^" + this.weekdays(mom, "").replace(".", "\\.?") + "$",
              "i"
            );
            this._shortWeekdaysParse[i] = new RegExp(
              "^" + this.weekdaysShort(mom, "").replace(".", "\\.?") + "$",
              "i"
            );
            this._minWeekdaysParse[i] = new RegExp(
              "^" + this.weekdaysMin(mom, "").replace(".", "\\.?") + "$",
              "i"
            );
          }
          if (!this._weekdaysParse[i]) {
            regex = "^" + this.weekdays(mom, "") + "|^" + this.weekdaysShort(mom, "") + "|^" + this.weekdaysMin(mom, "");
            this._weekdaysParse[i] = new RegExp(regex.replace(".", ""), "i");
          }
          if (strict && format2 === "dddd" && this._fullWeekdaysParse[i].test(weekdayName)) {
            return i;
          } else if (strict && format2 === "ddd" && this._shortWeekdaysParse[i].test(weekdayName)) {
            return i;
          } else if (strict && format2 === "dd" && this._minWeekdaysParse[i].test(weekdayName)) {
            return i;
          } else if (!strict && this._weekdaysParse[i].test(weekdayName)) {
            return i;
          }
        }
      }
      function getSetDayOfWeek(input) {
        if (!this.isValid()) {
          return input != null ? this : NaN;
        }
        var day = get$2(this, "Day");
        if (input != null) {
          input = parseWeekday(input, this.localeData());
          return this.add(input - day, "d");
        } else {
          return day;
        }
      }
      function getSetLocaleDayOfWeek(input) {
        if (!this.isValid()) {
          return input != null ? this : NaN;
        }
        var weekday = (this.day() + 7 - this.localeData()._week.dow) % 7;
        return input == null ? weekday : this.add(input - weekday, "d");
      }
      function getSetISODayOfWeek(input) {
        if (!this.isValid()) {
          return input != null ? this : NaN;
        }
        if (input != null) {
          var weekday = parseIsoWeekday(input, this.localeData());
          return this.day(this.day() % 7 ? weekday : weekday - 7);
        } else {
          return this.day() || 7;
        }
      }
      function weekdaysRegex(isStrict) {
        if (this._weekdaysParseExact) {
          if (!hasOwnProp(this, "_weekdaysRegex")) {
            computeWeekdaysParse.call(this);
          }
          if (isStrict) {
            return this._weekdaysStrictRegex;
          } else {
            return this._weekdaysRegex;
          }
        } else {
          if (!hasOwnProp(this, "_weekdaysRegex")) {
            this._weekdaysRegex = defaultWeekdaysRegex;
          }
          return this._weekdaysStrictRegex && isStrict ? this._weekdaysStrictRegex : this._weekdaysRegex;
        }
      }
      function weekdaysShortRegex(isStrict) {
        if (this._weekdaysParseExact) {
          if (!hasOwnProp(this, "_weekdaysRegex")) {
            computeWeekdaysParse.call(this);
          }
          if (isStrict) {
            return this._weekdaysShortStrictRegex;
          } else {
            return this._weekdaysShortRegex;
          }
        } else {
          if (!hasOwnProp(this, "_weekdaysShortRegex")) {
            this._weekdaysShortRegex = defaultWeekdaysShortRegex;
          }
          return this._weekdaysShortStrictRegex && isStrict ? this._weekdaysShortStrictRegex : this._weekdaysShortRegex;
        }
      }
      function weekdaysMinRegex(isStrict) {
        if (this._weekdaysParseExact) {
          if (!hasOwnProp(this, "_weekdaysRegex")) {
            computeWeekdaysParse.call(this);
          }
          if (isStrict) {
            return this._weekdaysMinStrictRegex;
          } else {
            return this._weekdaysMinRegex;
          }
        } else {
          if (!hasOwnProp(this, "_weekdaysMinRegex")) {
            this._weekdaysMinRegex = defaultWeekdaysMinRegex;
          }
          return this._weekdaysMinStrictRegex && isStrict ? this._weekdaysMinStrictRegex : this._weekdaysMinRegex;
        }
      }
      function computeWeekdaysParse() {
        function cmpLenRev(a, b) {
          return b.length - a.length;
        }
        var minPieces = [], shortPieces = [], longPieces = [], mixedPieces = [], i, mom, minp, shortp, longp;
        for (i = 0; i < 7; i++) {
          mom = createUTC([2e3, 1]).day(i);
          minp = regexEscape(this.weekdaysMin(mom, ""));
          shortp = regexEscape(this.weekdaysShort(mom, ""));
          longp = regexEscape(this.weekdays(mom, ""));
          minPieces.push(minp);
          shortPieces.push(shortp);
          longPieces.push(longp);
          mixedPieces.push(minp);
          mixedPieces.push(shortp);
          mixedPieces.push(longp);
        }
        minPieces.sort(cmpLenRev);
        shortPieces.sort(cmpLenRev);
        longPieces.sort(cmpLenRev);
        mixedPieces.sort(cmpLenRev);
        this._weekdaysRegex = new RegExp("^(" + mixedPieces.join("|") + ")", "i");
        this._weekdaysShortRegex = this._weekdaysRegex;
        this._weekdaysMinRegex = this._weekdaysRegex;
        this._weekdaysStrictRegex = new RegExp(
          "^(" + longPieces.join("|") + ")",
          "i"
        );
        this._weekdaysShortStrictRegex = new RegExp(
          "^(" + shortPieces.join("|") + ")",
          "i"
        );
        this._weekdaysMinStrictRegex = new RegExp(
          "^(" + minPieces.join("|") + ")",
          "i"
        );
      }
      function set(config) {
        var prop, i;
        clearMonthsParseCache(this, config);
        clearWeekdaysParseCache(this, config);
        for (i in config) {
          if (hasOwnProp(config, i)) {
            prop = config[i];
            if (isFunction(prop)) {
              this[i] = prop;
            } else {
              this["_" + i] = prop;
            }
          }
        }
        this._config = config;
        this._dayOfMonthOrdinalParseLenient = new RegExp(
          (this._dayOfMonthOrdinalParse.source || this._ordinalParse.source) + "|" + /\d{1,2}/.source
        );
      }
      function mergeConfigs(parentConfig, childConfig) {
        var res = extend({}, parentConfig), prop;
        for (prop in childConfig) {
          if (hasOwnProp(childConfig, prop)) {
            if (isObject(parentConfig[prop]) && isObject(childConfig[prop])) {
              res[prop] = {};
              extend(res[prop], parentConfig[prop]);
              extend(res[prop], childConfig[prop]);
            } else if (childConfig[prop] != null) {
              res[prop] = childConfig[prop];
            } else {
              delete res[prop];
            }
          }
        }
        for (prop in parentConfig) {
          if (hasOwnProp(parentConfig, prop) && !hasOwnProp(childConfig, prop) && isObject(parentConfig[prop])) {
            res[prop] = extend({}, res[prop]);
          }
        }
        return res;
      }
      function Locale(config) {
        if (config != null) {
          this.set(config);
        }
      }
      var keys;
      if (Object.keys) {
        keys = Object.keys;
      } else {
        keys = function(obj) {
          var i, res = [];
          for (i in obj) {
            if (hasOwnProp(obj, i)) {
              res.push(i);
            }
          }
          return res;
        };
      }
      var defaultCalendar = {
        sameDay: "[Today at] LT",
        nextDay: "[Tomorrow at] LT",
        nextWeek: "dddd [at] LT",
        lastDay: "[Yesterday at] LT",
        lastWeek: "[Last] dddd [at] LT",
        sameElse: "L"
      };
      function calendar$1(key, mom, now2) {
        var output = this._calendar[key] || this._calendar["sameElse"];
        return isFunction(output) ? output.call(mom, now2) : output;
      }
      var defaultLongDateFormat = {
        LTS: "h:mm:ss A",
        LT: "h:mm A",
        L: "MM/DD/YYYY",
        LL: "MMMM D, YYYY",
        LLL: "MMMM D, YYYY h:mm A",
        LLLL: "dddd, MMMM D, YYYY h:mm A"
      };
      function longDateFormat(key) {
        var format2 = this._longDateFormat[key], formatUpper = this._longDateFormat[key.toUpperCase()], formatCache = this._longDateFormatCache;
        if (format2 || !formatUpper) {
          return format2;
        }
        if (formatCache && formatCache[key] && formatCache[key].formatUpper === formatUpper) {
          return formatCache[key].format;
        }
        format2 = formatUpper.match(formattingTokens).map(function(tok) {
          if (tok === "MMMM" || tok === "MM" || tok === "DD" || tok === "dddd") {
            return tok.slice(1);
          }
          return tok;
        }).join("");
        if (!formatCache) {
          formatCache = this._longDateFormatCache = {};
        }
        formatCache[key] = {
          formatUpper,
          format: format2
        };
        return format2;
      }
      var defaultInvalidDate = "Invalid date";
      function invalidDate() {
        return this._invalidDate;
      }
      var defaultOrdinal = "%d", defaultDayOfMonthOrdinalParse = /\d{1,2}/;
      function ordinal(number) {
        return this._ordinal.replace("%d", number);
      }
      var defaultRelativeTime = {
        future: "in %s",
        past: "%s ago",
        s: "a few seconds",
        ss: "%d seconds",
        m: "a minute",
        mm: "%d minutes",
        h: "an hour",
        hh: "%d hours",
        d: "a day",
        dd: "%d days",
        w: "a week",
        ww: "%d weeks",
        M: "a month",
        MM: "%d months",
        y: "a year",
        yy: "%d years"
      };
      function relativeTimeWithoutPostformat(number, withoutSuffix, string, isFuture) {
        var output = this._relativeTime[string];
        return isFunction(output) ? output(number, withoutSuffix, string, isFuture) : output.replace(/%d/i, number);
      }
      function relativeTime$1(number, withoutSuffix, string, isFuture) {
        return this.postformat(
          relativeTimeWithoutPostformat.call(
            this,
            number,
            withoutSuffix,
            string,
            isFuture
          )
        );
      }
      function pastFutureWithoutPostformat(diff2, output) {
        var format2 = this._relativeTime[diff2 > 0 ? "future" : "past"];
        return isFunction(format2) ? format2(output) : format2.replace(/%s/i, output);
      }
      function pastFuture(diff2, output) {
        return this.postformat(
          pastFutureWithoutPostformat.call(this, diff2, output)
        );
      }
      function createDate(y, m, d, h, M, s, ms) {
        var date;
        if (y < 100 && y >= 0) {
          date = new Date(y + 400, m, d, h, M, s, ms);
          if (isFinite(date.getFullYear())) {
            date.setFullYear(y);
          }
        } else {
          date = new Date(y, m, d, h, M, s, ms);
        }
        return date;
      }
      function createUTCDate(y) {
        var date, args;
        if (y < 100 && y >= 0) {
          args = Array.prototype.slice.call(arguments);
          args[0] = y + 400;
          date = new Date(Date.UTC.apply(null, args));
          if (isFinite(date.getUTCFullYear())) {
            date.setUTCFullYear(y);
          }
        } else {
          date = new Date(Date.UTC.apply(null, arguments));
        }
        return date;
      }
      function firstWeekOffset(year, dow, doy) {
        var fwd = 7 + dow - doy, fwdlw = (7 + createUTCDate(year, 0, fwd).getUTCDay() - dow) % 7;
        return -fwdlw + fwd - 1;
      }
      function dayOfYearFromWeeks(year, week, weekday, dow, doy) {
        var localWeekday = (7 + weekday - dow) % 7, weekOffset = firstWeekOffset(year, dow, doy), dayOfYear = 1 + 7 * (week - 1) + localWeekday + weekOffset, resYear, resDayOfYear;
        if (dayOfYear <= 0) {
          resYear = year - 1;
          resDayOfYear = daysInYear(resYear) + dayOfYear;
        } else if (dayOfYear > daysInYear(year)) {
          resYear = year + 1;
          resDayOfYear = dayOfYear - daysInYear(year);
        } else {
          resYear = year;
          resDayOfYear = dayOfYear;
        }
        return {
          year: resYear,
          dayOfYear: resDayOfYear
        };
      }
      function weekOfYearFromDayOfYear(year, dayOfYear, dow, doy) {
        var weekOffset = firstWeekOffset(year, dow, doy), week = Math.floor((dayOfYear - weekOffset - 1) / 7) + 1, resWeek, resYear;
        if (week < 1) {
          resYear = year - 1;
          resWeek = week + weeksInYear(resYear, dow, doy);
        } else if (week > weeksInYear(year, dow, doy)) {
          resWeek = week - weeksInYear(year, dow, doy);
          resYear = year + 1;
        } else {
          resYear = year;
          resWeek = week;
        }
        return {
          week: resWeek,
          year: resYear
        };
      }
      function weekOfYear(mom, dow, doy) {
        return weekOfYearFromDayOfYear(mom.year(), mom.dayOfYear(), dow, doy);
      }
      function weekOfYearFromDate(year, month, date, dow, doy) {
        var dayOfYear = Math.round(
          (createUTCDate(year, month, date) - createUTCDate(year, 0, 1)) / 864e5
        ) + 1;
        return weekOfYearFromDayOfYear(year, dayOfYear, dow, doy);
      }
      function weeksInYear(year, dow, doy) {
        var weekOffset = firstWeekOffset(year, dow, doy), weekOffsetNext = firstWeekOffset(year + 1, dow, doy);
        return (daysInYear(year) - weekOffset + weekOffsetNext) / 7;
      }
      addFormatToken("w", ["ww", 2], "wo", "week");
      addFormatToken("W", ["WW", 2], "Wo", "isoWeek");
      addRegexToken("w", match1to2, match1to2NoLeadingZero);
      addRegexToken("ww", match1to2, match2);
      addRegexToken("W", match1to2, match1to2NoLeadingZero);
      addRegexToken("WW", match1to2, match2);
      addWeekParseToken(
        ["w", "ww", "W", "WW"],
        function(input, week, config, token2) {
          week[token2.substr(0, 1)] = toInt(input);
        }
      );
      function localeWeek(mom) {
        return weekOfYear(mom, this._week.dow, this._week.doy).week;
      }
      var defaultLocaleWeek = {
        dow: 0,
        // Sunday is the first day of the week.
        doy: 6
        // The week that contains Jan 6th is the first week of the year.
      };
      function localeFirstDayOfWeek() {
        return this._week.dow;
      }
      function localeFirstDayOfYear() {
        return this._week.doy;
      }
      function getSetWeek(input) {
        var week = this.localeData().week(this);
        return input == null ? week : this.add((input - week) * 7, "d");
      }
      function getSetISOWeek(input) {
        var week = weekOfYear(this, 1, 4).week;
        return input == null ? week : this.add((input - week) * 7, "d");
      }
      function hFormat() {
        return this.hours() % 12 || 12;
      }
      function kFormat() {
        return this.hours() || 24;
      }
      addFormatToken("H", ["HH", 2], 0, "hour");
      addFormatToken("h", ["hh", 2], 0, hFormat);
      addFormatToken("k", ["kk", 2], 0, kFormat);
      addFormatToken("hmm", 0, 0, function() {
        return "" + hFormat.apply(this) + zeroFill(this.minutes(), 2);
      });
      addFormatToken("hmmss", 0, 0, function() {
        return "" + hFormat.apply(this) + zeroFill(this.minutes(), 2) + zeroFill(this.seconds(), 2);
      });
      addFormatToken("Hmm", 0, 0, function() {
        return "" + this.hours() + zeroFill(this.minutes(), 2);
      });
      addFormatToken("Hmmss", 0, 0, function() {
        return "" + this.hours() + zeroFill(this.minutes(), 2) + zeroFill(this.seconds(), 2);
      });
      function meridiem(token2, lowercase) {
        addFormatToken(token2, 0, 0, function() {
          return this.localeData().meridiem(
            this.hours(),
            this.minutes(),
            lowercase
          );
        });
      }
      meridiem("a", true);
      meridiem("A", false);
      function matchMeridiem(isStrict, locale2) {
        return locale2._meridiemParse;
      }
      addRegexToken("a", matchMeridiem);
      addRegexToken("A", matchMeridiem);
      addRegexToken("H", match1to2, match1to2HasZero);
      addRegexToken("h", match1to2, match1to2NoLeadingZero);
      addRegexToken("k", match1to2, match1to2NoLeadingZero);
      addRegexToken("HH", match1to2, match2);
      addRegexToken("hh", match1to2, match2);
      addRegexToken("kk", match1to2, match2);
      addRegexToken("hmm", match3to4);
      addRegexToken("hmmss", match5to6);
      addRegexToken("Hmm", match3to4);
      addRegexToken("Hmmss", match5to6);
      addParseToken(["H", "HH"], HOUR);
      addParseToken(["k", "kk"], function(input, array, config) {
        var kInput = toInt(input);
        array[HOUR] = kInput === 24 ? 0 : kInput;
      });
      addParseToken(["a", "A"], function(input, array, config) {
        config._isPm = config._locale.isPM(input);
        config._meridiem = input;
      });
      addParseToken(["h", "hh"], function(input, array, config) {
        array[HOUR] = toInt(input);
        getParsingFlags(config).bigHour = true;
      });
      addParseToken("hmm", function(input, array, config) {
        var pos = input.length - 2;
        array[HOUR] = toInt(input.substr(0, pos));
        array[MINUTE] = toInt(input.substr(pos));
        getParsingFlags(config).bigHour = true;
      });
      addParseToken("hmmss", function(input, array, config) {
        var pos1 = input.length - 4, pos2 = input.length - 2;
        array[HOUR] = toInt(input.substr(0, pos1));
        array[MINUTE] = toInt(input.substr(pos1, 2));
        array[SECOND] = toInt(input.substr(pos2));
        getParsingFlags(config).bigHour = true;
      });
      addParseToken("Hmm", function(input, array, config) {
        var pos = input.length - 2;
        array[HOUR] = toInt(input.substr(0, pos));
        array[MINUTE] = toInt(input.substr(pos));
      });
      addParseToken("Hmmss", function(input, array, config) {
        var pos1 = input.length - 4, pos2 = input.length - 2;
        array[HOUR] = toInt(input.substr(0, pos1));
        array[MINUTE] = toInt(input.substr(pos1, 2));
        array[SECOND] = toInt(input.substr(pos2));
      });
      function localeIsPM(input) {
        return (input + "").toLowerCase().charAt(0) === "p";
      }
      var defaultLocaleMeridiemParse = /[ap]\.?m?\.?/i, getSetHour = makeGetSet("Hours", true);
      function localeMeridiem(hours2, minutes2, isLower) {
        if (hours2 > 11) {
          return isLower ? "pm" : "PM";
        } else {
          return isLower ? "am" : "AM";
        }
      }
      var baseConfig = {
        calendar: defaultCalendar,
        longDateFormat: defaultLongDateFormat,
        invalidDate: defaultInvalidDate,
        ordinal: defaultOrdinal,
        dayOfMonthOrdinalParse: defaultDayOfMonthOrdinalParse,
        relativeTime: defaultRelativeTime,
        months: defaultLocaleMonths,
        monthsShort: defaultLocaleMonthsShort,
        week: defaultLocaleWeek,
        weekdays: defaultLocaleWeekdays,
        weekdaysMin: defaultLocaleWeekdaysMin,
        weekdaysShort: defaultLocaleWeekdaysShort,
        meridiemParse: defaultLocaleMeridiemParse
      };
      var locales = {}, localeFamilies = {}, globalLocale;
      function commonPrefix(arr1, arr2) {
        var i, minl = Math.min(arr1.length, arr2.length);
        for (i = 0; i < minl; i += 1) {
          if (arr1[i] !== arr2[i]) {
            return i;
          }
        }
        return minl;
      }
      function normalizeLocale(key) {
        return key ? key.toLowerCase().replace("_", "-") : key;
      }
      function chooseLocale(names) {
        var i = 0, j, next, locale2, split;
        while (i < names.length) {
          split = normalizeLocale(names[i]).split("-");
          j = split.length;
          next = normalizeLocale(names[i + 1]);
          next = next ? next.split("-") : null;
          while (j > 0) {
            locale2 = loadLocale(split.slice(0, j).join("-"));
            if (locale2) {
              return locale2;
            }
            if (next && next.length >= j && commonPrefix(split, next) >= j - 1) {
              break;
            }
            j--;
          }
          i++;
        }
        return globalLocale;
      }
      function isLocaleNameSane(name) {
        return typeof name === "string" && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name);
      }
      function loadLocale(name) {
        var oldLocale = null, aliasedRequire, normalizedName;
        if (hasOwnProp(locales, name)) {
          return locales[name];
        }
        normalizedName = normalizeLocale(name);
        if (hasOwnProp(locales, normalizedName)) {
          return locales[normalizedName];
        }
        if (typeof module2 !== "undefined" && module2 && module2.exports && isLocaleNameSane(normalizedName)) {
          try {
            oldLocale = globalLocale._abbr;
            aliasedRequire = require;
            aliasedRequire("./locale/" + normalizedName);
            getSetGlobalLocale(oldLocale);
          } catch (e) {
            locales[normalizedName] = null;
          }
        }
        if (hasOwnProp(locales, normalizedName)) {
          return locales[normalizedName];
        }
      }
      function getSetGlobalLocale(key, values) {
        var data;
        if (key) {
          if (isUndefined(values)) {
            data = getLocale(key);
          } else {
            data = defineLocale(key, values);
          }
          if (data) {
            globalLocale = data;
          } else {
            if (typeof console !== "undefined" && console.warn) {
              console.warn(
                "Locale " + key + " not found. Did you forget to load it?"
              );
            }
          }
        }
        return globalLocale._abbr;
      }
      function defineLocale(name, config) {
        if (config !== null) {
          var locale2, parentConfig = baseConfig;
          config.abbr = name;
          if (locales[name] != null) {
            deprecateSimple(
              "defineLocaleOverride",
              "use moment.updateLocale(localeName, config) to change an existing locale. moment.defineLocale(localeName, config) should only be used for creating a new locale See http://momentjs.com/guides/#/warnings/define-locale/ for more info."
            );
            parentConfig = locales[name]._config;
          } else if (config.parentLocale != null) {
            if (locales[config.parentLocale] != null) {
              parentConfig = locales[config.parentLocale]._config;
            } else {
              locale2 = loadLocale(config.parentLocale);
              if (locale2 != null) {
                parentConfig = locale2._config;
              } else {
                if (!localeFamilies[config.parentLocale]) {
                  localeFamilies[config.parentLocale] = [];
                }
                localeFamilies[config.parentLocale].push({
                  name,
                  config
                });
                return null;
              }
            }
          }
          locales[name] = new Locale(mergeConfigs(parentConfig, config));
          if (localeFamilies[name]) {
            localeFamilies[name].forEach(function(x) {
              defineLocale(x.name, x.config);
            });
          }
          getSetGlobalLocale(name);
          return locales[name];
        } else {
          delete locales[name];
          return null;
        }
      }
      function updateLocale(name, config) {
        var locale2, tmpLocale = loadLocale(name), parentConfig = baseConfig;
        if (tmpLocale != null) {
          name = tmpLocale._abbr;
        }
        if (config != null) {
          if (locales[name] != null && locales[name].parentLocale != null) {
            locales[name].set(mergeConfigs(locales[name]._config, config));
          } else {
            if (tmpLocale != null) {
              parentConfig = tmpLocale._config;
            }
            config = mergeConfigs(parentConfig, config);
            if (tmpLocale == null) {
              config.abbr = name;
            }
            locale2 = new Locale(config);
            locale2.parentLocale = locales[name];
            locales[name] = locale2;
          }
          getSetGlobalLocale(name);
        } else {
          if (locales[name] != null) {
            if (locales[name].parentLocale != null) {
              locales[name] = locales[name].parentLocale;
              if (name === getSetGlobalLocale()) {
                getSetGlobalLocale(name);
              }
            } else if (locales[name] != null) {
              delete locales[name];
            }
          }
        }
        return locales[name];
      }
      function getLocale(key) {
        var locale2;
        if (key && key._locale && key._locale._abbr) {
          key = key._locale._abbr;
        }
        if (!key) {
          return globalLocale;
        }
        if (!isArray(key)) {
          locale2 = loadLocale(key);
          if (locale2) {
            return locale2;
          }
          key = [key];
        }
        return chooseLocale(key);
      }
      function listLocales() {
        return keys(locales);
      }
      function checkOverflow(m) {
        var overflow, a = m._a;
        if (a && getParsingFlags(m).overflow === -2) {
          overflow = a[MONTH] < 0 || a[MONTH] > 11 ? MONTH : a[DATE] < 1 || a[DATE] > daysInMonth(a[YEAR], a[MONTH]) ? DATE : a[HOUR] < 0 || a[HOUR] > 24 || a[HOUR] === 24 && (a[MINUTE] !== 0 || a[SECOND] !== 0 || a[MILLISECOND] !== 0) ? HOUR : a[MINUTE] < 0 || a[MINUTE] > 59 ? MINUTE : a[SECOND] < 0 || a[SECOND] > 59 ? SECOND : a[MILLISECOND] < 0 || a[MILLISECOND] > 999 ? MILLISECOND : -1;
          if (getParsingFlags(m)._overflowDayOfYear && (overflow < YEAR || overflow > DATE)) {
            overflow = DATE;
          }
          if (getParsingFlags(m)._overflowWeeks && overflow === -1) {
            overflow = WEEK;
          }
          if (getParsingFlags(m)._overflowWeekday && overflow === -1) {
            overflow = WEEKDAY;
          }
          getParsingFlags(m).overflow = overflow;
        }
        return m;
      }
      var extendedIsoRegex = /^\s*((?:[+-]\d{6}|\d{4})-(?:\d\d-\d\d|W\d\d-\d|W\d\d|\d\d\d|\d\d))(?:(T| )(\d\d(?::\d\d(?::\d\d(?:[.,]\d+)?)?)?)([+-]\d\d(?::?\d\d)?|\s*Z)?)?$/, basicIsoRegex = /^\s*((?:[+-]\d{6}|\d{4})(?:\d\d\d\d|W\d\d\d|W\d\d|\d\d\d|\d\d|))(?:(T| )(\d\d(?:\d\d(?:\d\d(?:[.,]\d+)?)?)?)([+-]\d\d(?::?\d\d)?|\s*Z)?)?$/, tzRegex = /Z|[+-]\d\d(?::?\d\d)?/, isoDates = [
        ["YYYYYY-MM-DD", /[+-]\d{6}-\d\d-\d\d/],
        ["YYYY-MM-DD", /\d{4}-\d\d-\d\d/],
        ["GGGG-[W]WW-E", /\d{4}-W\d\d-\d/],
        ["GGGG-[W]WW", /\d{4}-W\d\d/, false],
        ["YYYY-DDD", /\d{4}-\d{3}/],
        ["YYYY-MM", /\d{4}-\d\d/, false],
        ["YYYYYYMMDD", /[+-]\d{10}/],
        ["YYYYMMDD", /\d{8}/],
        ["GGGG[W]WWE", /\d{4}W\d{3}/],
        ["GGGG[W]WW", /\d{4}W\d{2}/, false],
        ["YYYYDDD", /\d{7}/],
        ["YYYYMM", /\d{6}/, false],
        ["YYYY", /\d{4}/, false]
      ], isoTimes = [
        ["HH:mm:ss.SSSS", /\d\d:\d\d:\d\d\.\d+/],
        ["HH:mm:ss,SSSS", /\d\d:\d\d:\d\d,\d+/],
        ["HH:mm:ss", /\d\d:\d\d:\d\d/],
        ["HH:mm", /\d\d:\d\d/],
        ["HHmmss.SSSS", /\d\d\d\d\d\d\.\d+/],
        ["HHmmss,SSSS", /\d\d\d\d\d\d,\d+/],
        ["HHmmss", /\d\d\d\d\d\d/],
        ["HHmm", /\d\d\d\d/],
        ["HH", /\d\d/]
      ], aspNetJsonRegex = /^\/?Date\((-?\d+)/i, rfc2822 = /^(?:(Mon|Tue|Wed|Thu|Fri|Sat|Sun),?\s)?(\d{1,2})\s(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s(\d{2,4})\s(\d\d):(\d\d)(?::(\d\d))?\s(?:(UT|GMT|[ECMP][SD]T)|([Zz])|([+-]\d{4}))$/, obsOffsets = {
        UT: 0,
        GMT: 0,
        EDT: -4 * 60,
        EST: -5 * 60,
        CDT: -5 * 60,
        CST: -6 * 60,
        MDT: -6 * 60,
        MST: -7 * 60,
        PDT: -7 * 60,
        PST: -8 * 60
      };
      function configFromISO(config) {
        var i, l, string = config._i, match = extendedIsoRegex.exec(string) || basicIsoRegex.exec(string), allowTime, dateFormat, timeFormat, tzFormat, isoDatesLen = isoDates.length, isoTimesLen = isoTimes.length;
        if (match) {
          getParsingFlags(config).iso = true;
          for (i = 0, l = isoDatesLen; i < l; i++) {
            if (isoDates[i][1].exec(match[1])) {
              dateFormat = isoDates[i][0];
              allowTime = isoDates[i][2] !== false;
              break;
            }
          }
          if (dateFormat == null) {
            config._isValid = false;
            return;
          }
          if (match[3]) {
            for (i = 0, l = isoTimesLen; i < l; i++) {
              if (isoTimes[i][1].exec(match[3])) {
                timeFormat = (match[2] || " ") + isoTimes[i][0];
                break;
              }
            }
            if (timeFormat == null) {
              config._isValid = false;
              return;
            }
          }
          if (!allowTime && timeFormat != null) {
            config._isValid = false;
            return;
          }
          if (match[4]) {
            if (tzRegex.exec(match[4])) {
              tzFormat = "Z";
            } else {
              config._isValid = false;
              return;
            }
          }
          config._f = dateFormat + (timeFormat || "") + (tzFormat || "");
          configFromStringAndFormat(config);
        } else {
          config._isValid = false;
        }
      }
      function extractFromRFC2822Strings(yearStr, monthStr, dayStr, hourStr, minuteStr, secondStr) {
        var result = [
          untruncateYear(yearStr),
          defaultLocaleMonthsShort.indexOf(monthStr),
          parseInt(dayStr, 10),
          parseInt(hourStr, 10),
          parseInt(minuteStr, 10)
        ];
        if (secondStr) {
          result.push(parseInt(secondStr, 10));
        }
        return result;
      }
      function untruncateYear(yearStr) {
        var year = parseInt(yearStr, 10);
        if (year <= 49) {
          return 2e3 + year;
        } else if (year <= 999) {
          return 1900 + year;
        }
        return year;
      }
      function preprocessRFC2822(s) {
        return s.replace(/\([^()]*\)|[\n\t]/g, " ").replace(/(\s\s+)/g, " ").replace(/^\s\s*/, "").replace(/\s\s*$/, "");
      }
      function checkWeekday(weekdayStr, parsedInput, config) {
        if (weekdayStr) {
          var weekdayProvided = defaultLocaleWeekdaysShort.indexOf(weekdayStr), weekdayActual = new Date(
            parsedInput[0],
            parsedInput[1],
            parsedInput[2]
          ).getDay();
          if (weekdayProvided !== weekdayActual) {
            getParsingFlags(config).weekdayMismatch = true;
            config._isValid = false;
            return false;
          }
        }
        return true;
      }
      function calculateOffset(obsOffset, militaryOffset, numOffset) {
        if (obsOffset) {
          return obsOffsets[obsOffset];
        } else if (militaryOffset) {
          return 0;
        } else {
          var hm = parseInt(numOffset, 10), m = hm % 100, h = (hm - m) / 100;
          return h * 60 + m;
        }
      }
      function configFromRFC2822(config) {
        var match = rfc2822.exec(preprocessRFC2822(config._i)), parsedArray;
        if (match) {
          parsedArray = extractFromRFC2822Strings(
            match[4],
            match[3],
            match[2],
            match[5],
            match[6],
            match[7]
          );
          if (!checkWeekday(match[1], parsedArray, config)) {
            return;
          }
          config._a = parsedArray;
          config._tzm = calculateOffset(match[8], match[9], match[10]);
          config._d = createUTCDate.apply(null, config._a);
          config._d.setUTCMinutes(config._d.getUTCMinutes() - config._tzm);
          getParsingFlags(config).rfc2822 = true;
        } else {
          config._isValid = false;
        }
      }
      function configFromString(config) {
        var matched = aspNetJsonRegex.exec(config._i);
        if (matched !== null) {
          config._d = /* @__PURE__ */ new Date(+matched[1]);
          return;
        }
        configFromISO(config);
        if (config._isValid === false) {
          delete config._isValid;
        } else {
          return;
        }
        configFromRFC2822(config);
        if (config._isValid === false) {
          delete config._isValid;
        } else {
          return;
        }
        if (config._strict) {
          config._isValid = false;
        } else {
          hooks.createFromInputFallback(config);
        }
      }
      hooks.createFromInputFallback = deprecate(
        "value provided is not in a recognized RFC2822 or ISO format. moment construction falls back to js Date(), which is not reliable across all browsers and versions. Non RFC2822/ISO date formats are discouraged. Please refer to http://momentjs.com/guides/#/warnings/js-date/ for more info.",
        function(config) {
          config._d = /* @__PURE__ */ new Date(config._i + (config._useUTC ? " UTC" : ""));
        }
      );
      function defaults(a, b, c) {
        if (a != null) {
          return a;
        }
        if (b != null) {
          return b;
        }
        return c;
      }
      function currentDateArray(config, now2, forWeek) {
        var hadWeekContext = Object.prototype.hasOwnProperty.call(
          config,
          "_isDefaultDatePartsForWeek"
        ), weekContext = config._isDefaultDatePartsForWeek;
        config._isDefaultDatePartsForWeek = !!forWeek;
        try {
          return hooks._getDefaultDateParts(config, now2, forWeek);
        } finally {
          if (hadWeekContext) {
            config._isDefaultDatePartsForWeek = weekContext;
          } else {
            delete config._isDefaultDatePartsForWeek;
          }
        }
      }
      function currentDateNow(config) {
        var now2 = config._defaultDatePartsNow;
        if (!now2) {
          return hooks.now();
        }
        if (!now2.hasValue) {
          now2.value = hooks.now();
          now2.hasValue = true;
        }
        return now2.value;
      }
      function getDefaultDateParts(config, now2, forWeek) {
        var useWeekDefaults = forWeek || config._isDefaultDatePartsForWeek, nowValue = useWeekDefaults ? createLocal(now2) : new Date(now2);
        if (useWeekDefaults) {
          return [nowValue.year(), nowValue.month(), nowValue.date()];
        }
        if (config._useUTC) {
          return [
            nowValue.getUTCFullYear(),
            nowValue.getUTCMonth(),
            nowValue.getUTCDate()
          ];
        }
        return [nowValue.getFullYear(), nowValue.getMonth(), nowValue.getDate()];
      }
      hooks._getDefaultDateParts = getDefaultDateParts;
      function configFromArray(config) {
        var i, date, input = [], now2, currentDate, expectedWeekday, yearToUse, dateIsDefaulted;
        if (config._d) {
          return;
        }
        if (config._a[YEAR] == null || config._a[MONTH] == null || config._a[DATE] == null) {
          now2 = currentDateNow(config);
          currentDate = currentDateArray(config, now2);
        }
        if (config._w && config._a[DATE] == null && config._a[MONTH] == null) {
          dayOfYearFromWeekInfo(config, currentDateArray(config, now2, true));
        }
        if (config._dayOfYear != null) {
          yearToUse = config._a[YEAR] != null ? config._a[YEAR] : currentDate[YEAR];
          if (config._dayOfYear > daysInYear(yearToUse) || config._dayOfYear === 0) {
            getParsingFlags(config)._overflowDayOfYear = true;
          }
          date = createUTCDate(yearToUse, 0, config._dayOfYear);
          config._a[MONTH] = date.getUTCMonth();
          config._a[DATE] = date.getUTCDate();
        }
        dateIsDefaulted = config._a[YEAR] == null || config._a[MONTH] == null || config._a[DATE] == null;
        for (i = 0; i < 3 && config._a[i] == null; ++i) {
          config._a[i] = input[i] = currentDate[i];
        }
        for (; i < 7; i++) {
          config._a[i] = input[i] = config._a[i] == null ? i === 2 ? 1 : 0 : config._a[i];
        }
        if (config._a[HOUR] === 24 && config._a[MINUTE] === 0 && config._a[SECOND] === 0 && config._a[MILLISECOND] === 0) {
          config._nextDay = true;
          config._a[HOUR] = 0;
        }
        config._d = (config._useUTC ? createUTCDate : createDate).apply(
          null,
          input
        );
        expectedWeekday = config._useUTC ? config._d.getUTCDay() : config._d.getDay();
        if (config._tzm != null) {
          config._d.setUTCMinutes(config._d.getUTCMinutes() - config._tzm);
        }
        if (config._nextDay) {
          config._a[HOUR] = 24;
        }
        if (config._w && typeof config._w.d !== "undefined" && !dateIsDefaulted && config._w.d !== expectedWeekday) {
          getParsingFlags(config).weekdayMismatch = true;
        }
      }
      function dayOfYearFromWeekInfo(config, currentDate) {
        var w, weekYear, week, weekday, dow, doy, temp, weekdayOverflow, curWeek;
        w = config._w;
        if (w.GG != null || w.W != null || w.E != null) {
          dow = 1;
          doy = 4;
          weekYear = defaults(
            w.GG,
            config._a[YEAR],
            weekOfYearFromDate(
              currentDate[YEAR],
              currentDate[MONTH],
              currentDate[DATE],
              1,
              4
            ).year
          );
          week = defaults(w.W, 1);
          weekday = defaults(w.E, 1);
          if (weekday < 1 || weekday > 7) {
            weekdayOverflow = true;
          }
        } else {
          dow = config._locale._week.dow;
          doy = config._locale._week.doy;
          curWeek = weekOfYearFromDate(
            currentDate[YEAR],
            currentDate[MONTH],
            currentDate[DATE],
            dow,
            doy
          );
          weekYear = defaults(w.gg, config._a[YEAR], curWeek.year);
          week = defaults(w.w, curWeek.week);
          if (w.d != null) {
            weekday = w.d;
            if (weekday < 0 || weekday > 6) {
              weekdayOverflow = true;
            }
          } else if (w.e != null) {
            weekday = w.e + dow;
            if (w.e < 0 || w.e > 6) {
              weekdayOverflow = true;
            }
          } else {
            weekday = dow;
          }
        }
        if (week < 1 || week > weeksInYear(weekYear, dow, doy)) {
          getParsingFlags(config)._overflowWeeks = true;
        } else if (weekdayOverflow != null) {
          getParsingFlags(config)._overflowWeekday = true;
        } else {
          temp = dayOfYearFromWeeks(weekYear, week, weekday, dow, doy);
          config._a[YEAR] = temp.year;
          config._dayOfYear = temp.dayOfYear;
        }
      }
      hooks.ISO_8601 = function() {
      };
      hooks.RFC_2822 = function() {
      };
      function configFromStringAndFormat(config) {
        if (config._f === hooks.ISO_8601) {
          configFromISO(config);
          return;
        }
        if (config._f === hooks.RFC_2822) {
          configFromRFC2822(config);
          return;
        }
        config._a = [];
        getParsingFlags(config).empty = true;
        var string = "" + config._i, i, parsedInput, tokens2, token2, skipped, stringLength = string.length, totalParsedInputLength = 0, era, tokenLen;
        tokens2 = expandFormat(config._f, config._locale).match(formattingTokens) || [];
        tokenLen = tokens2.length;
        for (i = 0; i < tokenLen; i++) {
          token2 = tokens2[i];
          parsedInput = (string.match(getParseRegexForToken(token2, config)) || [])[0];
          if (parsedInput) {
            skipped = string.substr(0, string.indexOf(parsedInput));
            if (skipped.length > 0) {
              getParsingFlags(config).unusedInput.push(skipped);
            }
            string = string.slice(
              string.indexOf(parsedInput) + parsedInput.length
            );
            totalParsedInputLength += parsedInput.length;
          }
          if (formatTokenFunctions[token2]) {
            if (parsedInput) {
              getParsingFlags(config).empty = false;
            } else {
              getParsingFlags(config).unusedTokens.push(token2);
            }
            addTimeToArrayFromToken(token2, parsedInput, config);
          } else if (config._strict && !parsedInput) {
            getParsingFlags(config).unusedTokens.push(token2);
          }
        }
        getParsingFlags(config).charsLeftOver = stringLength - totalParsedInputLength;
        if (string.length > 0) {
          getParsingFlags(config).unusedInput.push(string);
        }
        if (config._a[HOUR] <= 12 && getParsingFlags(config).bigHour === true && config._a[HOUR] > 0) {
          getParsingFlags(config).bigHour = void 0;
        }
        getParsingFlags(config).parsedDateParts = config._a.slice(0);
        getParsingFlags(config).meridiem = config._meridiem;
        config._a[HOUR] = meridiemFixWrap(
          config._locale,
          config._a[HOUR],
          config._meridiem
        );
        era = getParsingFlags(config).era;
        if (era !== null) {
          config._a[YEAR] = config._locale.erasConvertYear(era, config._a[YEAR]);
        }
        configFromArray(config);
        checkOverflow(config);
      }
      function meridiemFixWrap(locale2, hour, meridiem2) {
        var isPm;
        if (meridiem2 == null) {
          return hour;
        }
        if (locale2.meridiemHour != null) {
          return locale2.meridiemHour(hour, meridiem2);
        } else if (locale2.isPM != null) {
          isPm = locale2.isPM(meridiem2);
          if (isPm && hour < 12) {
            hour += 12;
          }
          if (!isPm && hour === 12) {
            hour = 0;
          }
          return hour;
        } else {
          return hour;
        }
      }
      function configFromStringAndArray(config) {
        var tempConfig, bestMoment, scoreToBeat, i, currentScore, validFormatFound, bestFormatIsValid = false, defaultDatePartsNow = {}, configfLen = config._f.length;
        if (configfLen === 0) {
          getParsingFlags(config).invalidFormat = true;
          config._d = /* @__PURE__ */ new Date(NaN);
          return;
        }
        for (i = 0; i < configfLen; i++) {
          currentScore = 0;
          validFormatFound = false;
          tempConfig = copyConfig({}, config);
          if (config._useUTC != null) {
            tempConfig._useUTC = config._useUTC;
          }
          tempConfig._defaultDatePartsNow = defaultDatePartsNow;
          tempConfig._f = config._f[i];
          configFromStringAndFormat(tempConfig);
          if (isValid$2(tempConfig)) {
            validFormatFound = true;
          }
          currentScore += getParsingFlags(tempConfig).charsLeftOver;
          currentScore += getParsingFlags(tempConfig).unusedTokens.length * 10;
          getParsingFlags(tempConfig).score = currentScore;
          if (!bestFormatIsValid) {
            if (scoreToBeat == null || currentScore < scoreToBeat || validFormatFound) {
              scoreToBeat = currentScore;
              bestMoment = tempConfig;
              if (validFormatFound) {
                bestFormatIsValid = true;
              }
            }
          } else {
            if (currentScore < scoreToBeat) {
              scoreToBeat = currentScore;
              bestMoment = tempConfig;
            }
          }
        }
        extend(config, bestMoment || tempConfig);
      }
      function configFromObject(config) {
        if (config._d) {
          return;
        }
        var i = normalizeObjectUnits(config._i), dayOrDate = i.day === void 0 ? i.date : i.day;
        config._a = map(
          [i.year, i.month, dayOrDate, i.hour, i.minute, i.second, i.millisecond],
          function(obj) {
            return obj && parseInt(obj, 10);
          }
        );
        configFromArray(config);
      }
      function createFromConfig(config) {
        var res = new Moment(checkOverflow(prepareConfig(config)));
        if (res._nextDay) {
          res.add(1, "d");
          res._nextDay = void 0;
        }
        return res;
      }
      function prepareConfig(config) {
        var input = config._i, format2 = config._f;
        config._locale = config._locale || getLocale(config._l);
        if (input === null || format2 === void 0 && input === "") {
          return createInvalid$1({ nullInput: true });
        }
        if (typeof input === "string") {
          config._i = input = config._locale.preparse(input);
        }
        if (isMoment(input)) {
          return new Moment(checkOverflow(input));
        } else if (isDate(input)) {
          config._d = input;
        } else if (isArray(format2)) {
          configFromStringAndArray(config);
        } else if (format2) {
          configFromStringAndFormat(config);
        } else {
          configFromInput(config);
        }
        if (!isValid$2(config)) {
          config._d = null;
        }
        return config;
      }
      function configFromInput(config) {
        var input = config._i;
        if (isUndefined(input)) {
          config._d = new Date(hooks.now());
        } else if (isDate(input)) {
          config._d = new Date(input.valueOf());
        } else if (typeof input === "string") {
          configFromString(config);
        } else if (isArray(input)) {
          config._a = map(input.slice(0), function(obj) {
            return parseInt(obj, 10);
          });
          configFromArray(config);
        } else if (isObject(input)) {
          configFromObject(config);
        } else if (isNumber(input)) {
          config._d = new Date(input);
        } else {
          hooks.createFromInputFallback(config);
        }
      }
      function createLocalOrUTC(input, format2, locale2, strict, isUTC) {
        var c = {};
        if (format2 === true || format2 === false) {
          strict = format2;
          format2 = void 0;
        }
        if (locale2 === true || locale2 === false) {
          strict = locale2;
          locale2 = void 0;
        }
        if (isObject(input) && isObjectEmpty(input) || isArray(input) && input.length === 0) {
          input = void 0;
        }
        c._isAMomentObject = true;
        c._useUTC = c._isUTC = isUTC;
        c._l = locale2;
        c._i = input;
        c._f = format2;
        c._strict = strict;
        return createFromConfig(c);
      }
      function createLocal(input, format2, locale2, strict) {
        return createLocalOrUTC(input, format2, locale2, strict, false);
      }
      var prototypeMin = deprecate(
        "moment().min is deprecated, use moment.max instead. http://momentjs.com/guides/#/warnings/min-max/",
        function() {
          var other = createLocal.apply(null, arguments);
          if (this.isValid() && other.isValid()) {
            return other < this ? this : other;
          } else {
            return createInvalid$1();
          }
        }
      ), prototypeMax = deprecate(
        "moment().max is deprecated, use moment.min instead. http://momentjs.com/guides/#/warnings/min-max/",
        function() {
          var other = createLocal.apply(null, arguments);
          if (this.isValid() && other.isValid()) {
            return other > this ? this : other;
          } else {
            return createInvalid$1();
          }
        }
      );
      function pickBy(fn, moments) {
        var res, i;
        if (moments.length === 1 && isArray(moments[0])) {
          moments = moments[0];
        }
        if (!moments.length) {
          return createLocal();
        }
        for (i = 0; i < moments.length; ++i) {
          if (isMoment(moments[i])) {
            res = moments[i];
            break;
          }
        }
        if (!res) {
          return createInvalid$1();
        }
        for (++i; i < moments.length; ++i) {
          if (isMoment(moments[i]) && (!moments[i].isValid() || moments[i][fn](res))) {
            res = moments[i];
          }
        }
        return res;
      }
      function min() {
        var args = [].slice.call(arguments, 0);
        return pickBy("isBefore", args);
      }
      function max() {
        var args = [].slice.call(arguments, 0);
        return pickBy("isAfter", args);
      }
      var now = function() {
        return Date.now ? Date.now() : +/* @__PURE__ */ new Date();
      };
      var ordering = [
        "year",
        "quarter",
        "month",
        "week",
        "day",
        "hour",
        "minute",
        "second",
        "millisecond"
      ];
      function isDurationValid(m) {
        var key, unitHasDecimal = false, i, orderLen = ordering.length;
        for (key in m) {
          if (hasOwnProp(m, key) && !(indexOf.call(ordering, key) !== -1 && (m[key] == null || !isNaN(m[key])))) {
            return false;
          }
        }
        for (i = 0; i < orderLen; ++i) {
          if (m[ordering[i]]) {
            if (unitHasDecimal) {
              return false;
            }
            if (parseFloat(m[ordering[i]]) !== toInt(m[ordering[i]])) {
              unitHasDecimal = true;
            }
          }
        }
        return true;
      }
      function isValid$1() {
        return this._isValid;
      }
      function createInvalid() {
        return createDuration(NaN);
      }
      function Duration(duration) {
        var normalizedInput = normalizeObjectUnits(duration), years2 = normalizedInput.year || 0, quarters = normalizedInput.quarter || 0, months2 = normalizedInput.month || 0, weeks2 = normalizedInput.week || normalizedInput.isoWeek || 0, days2 = normalizedInput.day || 0, hours2 = normalizedInput.hour || 0, minutes2 = normalizedInput.minute || 0, seconds2 = normalizedInput.second || 0, milliseconds2 = normalizedInput.millisecond || 0;
        this._isValid = isDurationValid(normalizedInput);
        this._milliseconds = +milliseconds2 + seconds2 * 1e3 + // 1000
        minutes2 * 6e4 + // 1000 * 60
        hours2 * 1e3 * 60 * 60;
        this._days = +days2 + weeks2 * 7;
        this._months = +months2 + quarters * 3 + years2 * 12;
        this._data = {};
        this._locale = getLocale();
        this._bubble();
      }
      function isDuration(obj) {
        return obj instanceof Duration;
      }
      function absRound(number) {
        if (number < 0) {
          return Math.round(-1 * number) * -1;
        } else {
          return Math.round(number);
        }
      }
      function compareArrays(array1, array2, dontConvert) {
        var len = Math.min(array1.length, array2.length), lengthDiff = Math.abs(array1.length - array2.length), diffs = 0, i;
        for (i = 0; i < len; i++) {
          if (toInt(array1[i]) !== toInt(array2[i])) {
            diffs++;
          }
        }
        return diffs + lengthDiff;
      }
      function offset(token2, separator) {
        addFormatToken(token2, 0, 0, function() {
          var offset2 = this.utcOffset(), sign2 = "+";
          if (offset2 < 0) {
            offset2 = -offset2;
            sign2 = "-";
          }
          return sign2 + zeroFill(~~(offset2 / 60), 2) + separator + zeroFill(~~offset2 % 60, 2);
        });
      }
      offset("Z", ":");
      offset("ZZ", "");
      addRegexToken("Z", matchShortOffset);
      addRegexToken("ZZ", matchShortOffset);
      addParseToken(["Z", "ZZ"], function(input, array, config) {
        var offset2 = offsetFromString(matchShortOffset, input);
        config._useUTC = true;
        config._tzm = offset2;
        if (offset2 === null) {
          getParsingFlags(config).invalidOffset = input;
        }
      });
      var chunkOffset = /([\+\-]|\d\d)/gi;
      function offsetFromString(matcher, string) {
        var matches = (string || "").match(matcher), chunk, parts, minutes2;
        if (matches === null) {
          return null;
        }
        chunk = matches[matches.length - 1] || [];
        parts = (chunk + "").match(chunkOffset) || ["-", 0, 0];
        minutes2 = +(parts[1] * 60) + toInt(parts[2]);
        if (toInt(parts[2]) > 59 || (parts[0] === "+" ? minutes2 > 14 * 60 : minutes2 > 12 * 60)) {
          return null;
        }
        return minutes2 === 0 ? 0 : parts[0] === "+" ? minutes2 : -minutes2;
      }
      function cloneWithOffset(input, model) {
        var res, diff2;
        if (model._isUTC) {
          res = model.clone();
          diff2 = (isMoment(input) || isDate(input) ? input.valueOf() : createLocal(input).valueOf()) - res.valueOf();
          res._d.setTime(res._d.valueOf() + diff2);
          hooks.updateOffset(res, false);
          return res;
        } else {
          return createLocal(input).local();
        }
      }
      function getDateOffset(m) {
        return -Math.round(m._d.getTimezoneOffset());
      }
      hooks.updateOffset = function() {
      };
      function getSetOffset(input, keepLocalTime, keepMinutes) {
        var offset2 = this._offset || 0, localAdjust;
        if (!this.isValid()) {
          return input != null ? this : NaN;
        }
        if (input != null) {
          if (typeof input === "string") {
            input = offsetFromString(matchShortOffset, input);
            if (input === null) {
              return this;
            }
          } else if (Math.abs(input) < 16 && !keepMinutes) {
            input = input * 60;
          }
          if (!this._isUTC && keepLocalTime) {
            localAdjust = getDateOffset(this);
          }
          this._offset = input;
          this._isUTC = true;
          if (localAdjust != null) {
            this.add(localAdjust, "m");
          }
          if (offset2 !== input) {
            if (!keepLocalTime || this._changeInProgress) {
              addSubtract$1(
                this,
                createDuration(input - offset2, "m"),
                1,
                false
              );
            } else if (!this._changeInProgress) {
              this._changeInProgress = true;
              hooks.updateOffset(this, true);
              this._changeInProgress = null;
            }
          }
          return this;
        } else {
          return this._isUTC ? offset2 : getDateOffset(this);
        }
      }
      function getSetZone(input, keepLocalTime) {
        if (input != null) {
          if (typeof input !== "string") {
            input = -input;
          }
          this.utcOffset(input, keepLocalTime);
          return this;
        } else {
          return -this.utcOffset();
        }
      }
      function setOffsetToUTC(keepLocalTime) {
        return this.utcOffset(0, keepLocalTime);
      }
      function setOffsetToLocal(keepLocalTime) {
        if (this._isUTC) {
          this.utcOffset(0, keepLocalTime);
          this._isUTC = false;
          if (keepLocalTime) {
            this.subtract(getDateOffset(this), "m");
          }
        }
        return this;
      }
      function setOffsetToParsedOffset() {
        if (this._tzm != null) {
          this.utcOffset(this._tzm, false, true);
        } else if (typeof this._i === "string") {
          var tZone = offsetFromString(matchOffset, this._i);
          if (tZone != null) {
            this.utcOffset(tZone);
          } else {
            this.utcOffset(0, true);
          }
        }
        return this;
      }
      function hasAlignedHourOffset(input) {
        if (!this.isValid()) {
          return false;
        }
        input = input ? createLocal(input).utcOffset() : 0;
        return (this.utcOffset() - input) % 60 === 0;
      }
      function isDaylightSavingTime() {
        return this.utcOffset() > this.clone().month(0).utcOffset() || this.utcOffset() > this.clone().month(5).utcOffset();
      }
      function isDaylightSavingTimeShifted() {
        if (!isUndefined(this._isDSTShifted)) {
          return this._isDSTShifted;
        }
        var c = {}, other;
        copyConfig(c, this);
        c = prepareConfig(c);
        if (c._a) {
          other = c._isUTC ? createUTC(c._a) : createLocal(c._a);
          this._isDSTShifted = this.isValid() && compareArrays(c._a, other.toArray()) > 0;
        } else {
          this._isDSTShifted = false;
        }
        return this._isDSTShifted;
      }
      function isLocal() {
        return this.isValid() ? !this._isUTC : false;
      }
      function isUtcOffset() {
        return this.isValid() ? this._isUTC : false;
      }
      function isUtc() {
        return this.isValid() ? this._isUTC && this._offset === 0 : false;
      }
      var aspNetRegex = /^(-|\+)?(?:(\d*)[. ])?(\d+):(\d+)(?::(\d+)(\.\d*)?)?$/, isoRegex = /^(-|\+)?P(?:([-+]?[0-9,.]*)Y)?(?:([-+]?[0-9,.]*)M)?(?:([-+]?[0-9,.]*)W)?(?:([-+]?[0-9,.]*)D)?(?:T(?:([-+]?[0-9,.]*)H)?(?:([-+]?[0-9,.]*)M)?(?:([-+]?[0-9,.]*)S)?)?$/;
      function createDuration(input, key) {
        var duration = input, match = null, sign2, ret, diffRes;
        if (isDuration(input)) {
          duration = {
            ms: input._milliseconds,
            d: input._days,
            M: input._months
          };
        } else if (isNumber(input) || !isNaN(+input)) {
          duration = {};
          if (key) {
            duration[key] = +input;
          } else {
            duration.milliseconds = +input;
          }
        } else if (match = aspNetRegex.exec(input)) {
          sign2 = match[1] === "-" ? -1 : 1;
          duration = {
            y: 0,
            d: toInt(match[DATE]) * sign2,
            h: toInt(match[HOUR]) * sign2,
            m: toInt(match[MINUTE]) * sign2,
            s: toInt(match[SECOND]) * sign2,
            ms: toInt(absRound(match[MILLISECOND] * 1e3)) * sign2
            // the millisecond decimal point is included in the match
          };
        } else if (match = isoRegex.exec(input)) {
          sign2 = match[1] === "-" ? -1 : 1;
          duration = {
            y: parseIso(match[2], sign2),
            M: parseIso(match[3], sign2),
            w: parseIso(match[4], sign2),
            d: parseIso(match[5], sign2),
            h: parseIso(match[6], sign2),
            m: parseIso(match[7], sign2),
            s: parseIso(match[8], sign2)
          };
        } else if (duration == null) {
          duration = {};
        } else if (typeof duration === "object" && ("from" in duration || "to" in duration)) {
          diffRes = momentsDifference(
            createLocal(duration.from),
            createLocal(duration.to)
          );
          duration = {};
          duration.ms = diffRes.milliseconds;
          duration.M = diffRes.months;
        }
        ret = new Duration(duration);
        if (isDuration(input) && hasOwnProp(input, "_locale")) {
          ret._locale = input._locale;
        }
        if (isDuration(input) && hasOwnProp(input, "_isValid")) {
          ret._isValid = input._isValid;
        }
        return ret;
      }
      createDuration.fn = Duration.prototype;
      createDuration.invalid = createInvalid;
      function parseIso(inp, sign2) {
        var res = inp && parseFloat(inp.replace(",", "."));
        return (isNaN(res) ? 0 : res) * sign2;
      }
      function positiveMomentsDifference(base, other) {
        var res = {};
        res.months = other.month() - base.month() + (other.year() - base.year()) * 12;
        if (base.clone().add(res.months, "M").isAfter(other)) {
          --res.months;
        }
        res.milliseconds = +other - +base.clone().add(res.months, "M");
        return res;
      }
      function momentsDifference(base, other) {
        var res;
        if (!(base.isValid() && other.isValid())) {
          return { milliseconds: 0, months: 0 };
        }
        other = cloneWithOffset(other, base);
        if (base.isBefore(other)) {
          res = positiveMomentsDifference(base, other);
        } else {
          res = positiveMomentsDifference(other, base);
          res.milliseconds = -res.milliseconds;
          res.months = -res.months;
        }
        return res;
      }
      function createAdder(direction, name) {
        return function(val, period) {
          var dur, tmp;
          if (period !== null && !isNaN(+period)) {
            deprecateSimple(
              name,
              "moment()." + name + "(period, number) is deprecated. Please use moment()." + name + "(number, period). See http://momentjs.com/guides/#/warnings/add-inverted-param/ for more info."
            );
            tmp = val;
            val = period;
            period = tmp;
          }
          dur = createDuration(val, period);
          addSubtract$1(this, dur, direction);
          return this;
        };
      }
      function addSubtract$1(mom, duration, isAdding, updateOffset) {
        var milliseconds2 = duration._milliseconds, days2 = absRound(duration._days), months2 = absRound(duration._months);
        if (!mom.isValid()) {
          return;
        }
        updateOffset = updateOffset == null ? true : updateOffset;
        if (months2) {
          setMonth(mom, get$2(mom, "Month") + months2 * isAdding);
        }
        if (days2) {
          set$1(mom, "Date", get$2(mom, "Date") + days2 * isAdding);
        }
        if (milliseconds2) {
          mom._d.setTime(mom._d.valueOf() + milliseconds2 * isAdding);
        }
        if (updateOffset) {
          hooks.updateOffset(mom, days2 || months2);
        }
      }
      var add$1 = createAdder(1, "add"), subtract$1 = createAdder(-1, "subtract");
      function isString(input) {
        return typeof input === "string" || input instanceof String;
      }
      function isMomentInput(input) {
        return isMoment(input) || isDate(input) || isString(input) || isNumber(input) || isNumberOrStringArray(input) || isMomentInputObject(input) || input === null || input === void 0;
      }
      function isMomentInputObject(input) {
        var objectTest = isObject(input) && !isObjectEmpty(input), propertyTest = false, properties = [
          "years",
          "year",
          "y",
          "months",
          "month",
          "M",
          "days",
          "day",
          "d",
          "dates",
          "date",
          "D",
          "hours",
          "hour",
          "h",
          "minutes",
          "minute",
          "m",
          "seconds",
          "second",
          "s",
          "milliseconds",
          "millisecond",
          "ms"
        ], i, property, propertyLen = properties.length;
        for (i = 0; i < propertyLen; i += 1) {
          property = properties[i];
          propertyTest = propertyTest || hasOwnProp(input, property);
        }
        return objectTest && propertyTest;
      }
      function isNumberOrStringArray(input) {
        var arrayTest = isArray(input), dataTypeTest = false;
        if (arrayTest) {
          dataTypeTest = input.filter(function(item) {
            return !isNumber(item) && isString(input);
          }).length === 0;
        }
        return arrayTest && dataTypeTest;
      }
      function isCalendarSpec(input) {
        var objectTest = isObject(input) && !isObjectEmpty(input), propertyTest = false, properties = [
          "sameDay",
          "nextDay",
          "lastDay",
          "nextWeek",
          "lastWeek",
          "sameElse"
        ], i, property;
        for (i = 0; i < properties.length; i += 1) {
          property = properties[i];
          propertyTest = propertyTest || hasOwnProp(input, property);
        }
        return objectTest && propertyTest;
      }
      function getCalendarFormat(myMoment, now2) {
        var diff2 = myMoment.diff(now2, "days", true);
        return diff2 < -6 ? "sameElse" : diff2 < -1 ? "lastWeek" : diff2 < 0 ? "lastDay" : diff2 < 1 ? "sameDay" : diff2 < 2 ? "nextDay" : diff2 < 7 ? "nextWeek" : "sameElse";
      }
      function calendar(time, formats) {
        if (arguments.length === 1) {
          if (!arguments[0]) {
            time = void 0;
            formats = void 0;
          } else if (isMomentInput(arguments[0])) {
            time = arguments[0];
            formats = void 0;
          } else if (isCalendarSpec(arguments[0])) {
            formats = arguments[0];
            time = void 0;
          }
        }
        var now2 = time || createLocal(), sod = cloneWithOffset(now2, this).startOf("day"), format2 = hooks.calendarFormat(this, sod) || "sameElse", output = formats && (isFunction(formats[format2]) ? formats[format2].call(this, now2) : formats[format2]);
        return this.format(
          output || this.localeData().calendar(format2, this, createLocal(now2))
        );
      }
      function clone$1() {
        return new Moment(this);
      }
      function isAfter(input, units) {
        var localInput = isMoment(input) ? input : createLocal(input);
        if (!(this.isValid() && localInput.isValid())) {
          return false;
        }
        units = normalizeUnits(units) || "millisecond";
        if (units === "millisecond") {
          return this.valueOf() > localInput.valueOf();
        } else {
          return localInput.valueOf() < this.clone().startOf(units).valueOf();
        }
      }
      function isBefore(input, units) {
        var localInput = isMoment(input) ? input : createLocal(input);
        if (!(this.isValid() && localInput.isValid())) {
          return false;
        }
        units = normalizeUnits(units) || "millisecond";
        if (units === "millisecond") {
          return this.valueOf() < localInput.valueOf();
        } else {
          return this.clone().endOf(units).valueOf() < localInput.valueOf();
        }
      }
      function isBetween(from2, to2, units, inclusivity) {
        var localFrom = isMoment(from2) ? from2 : createLocal(from2), localTo = isMoment(to2) ? to2 : createLocal(to2);
        if (!(this.isValid() && localFrom.isValid() && localTo.isValid())) {
          return false;
        }
        inclusivity = inclusivity || "()";
        return (inclusivity[0] === "(" ? this.isAfter(localFrom, units) : !this.isBefore(localFrom, units)) && (inclusivity[1] === ")" ? this.isBefore(localTo, units) : !this.isAfter(localTo, units));
      }
      function isSame(input, units) {
        var localInput = isMoment(input) ? input : createLocal(input), inputMs;
        if (!(this.isValid() && localInput.isValid())) {
          return false;
        }
        units = normalizeUnits(units) || "millisecond";
        if (units === "millisecond") {
          return this.valueOf() === localInput.valueOf();
        } else {
          inputMs = localInput.valueOf();
          return this.clone().startOf(units).valueOf() <= inputMs && inputMs <= this.clone().endOf(units).valueOf();
        }
      }
      function isSameOrAfter(input, units) {
        return this.isSame(input, units) || this.isAfter(input, units);
      }
      function isSameOrBefore(input, units) {
        return this.isSame(input, units) || this.isBefore(input, units);
      }
      function diff(input, units, asFloat) {
        var that, zoneDelta, output;
        if (!this.isValid()) {
          return NaN;
        }
        that = cloneWithOffset(input, this);
        if (!that.isValid()) {
          return NaN;
        }
        zoneDelta = (that.utcOffset() - this.utcOffset()) * 6e4;
        units = normalizeUnits(units);
        switch (units) {
          case "year":
            output = monthDiff(this, that) / 12;
            break;
          case "month":
            output = monthDiff(this, that);
            break;
          case "quarter":
            output = monthDiff(this, that) / 3;
            break;
          case "second":
            output = (this - that) / 1e3;
            break;
          // 1000
          case "minute":
            output = (this - that) / 6e4;
            break;
          // 1000 * 60
          case "hour":
            output = (this - that) / 36e5;
            break;
          // 1000 * 60 * 60
          case "day":
            output = (this - that - zoneDelta) / 864e5;
            break;
          // 1000 * 60 * 60 * 24, negate dst
          case "week":
            output = (this - that - zoneDelta) / 6048e5;
            break;
          // 1000 * 60 * 60 * 24 * 7, negate dst
          default:
            output = this - that;
        }
        return asFloat ? output : absFloor(output);
      }
      function monthDiff(a, b) {
        if (a.date() < b.date()) {
          return -monthDiff(b, a);
        }
        var wholeMonthDiff = (b.year() - a.year()) * 12 + (b.month() - a.month()), anchor = a.clone().add(wholeMonthDiff, "months"), anchor2, adjust;
        if (b - anchor < 0) {
          anchor2 = a.clone().add(wholeMonthDiff - 1, "months");
          adjust = (b - anchor) / (anchor - anchor2);
        } else {
          anchor2 = a.clone().add(wholeMonthDiff + 1, "months");
          adjust = (b - anchor) / (anchor2 - anchor);
        }
        return -(wholeMonthDiff + adjust) || 0;
      }
      hooks.defaultFormat = "YYYY-MM-DDTHH:mm:ssZ";
      hooks.defaultFormatUtc = "YYYY-MM-DDTHH:mm:ss[Z]";
      function toString() {
        return this.clone().locale("en").format("ddd MMM DD YYYY HH:mm:ss [GMT]ZZ");
      }
      function toISOString$1(keepOffset) {
        if (!this.isValid()) {
          return null;
        }
        var utc = keepOffset !== true, m = utc ? this.clone().utc() : this;
        if (m.year() < 0 || m.year() > 9999) {
          return formatMoment(
            m,
            utc ? "YYYYYY-MM-DD[T]HH:mm:ss.SSS[Z]" : "YYYYYY-MM-DD[T]HH:mm:ss.SSSZ"
          );
        }
        if (isFunction(Date.prototype.toISOString)) {
          if (utc) {
            return this.toDate().toISOString();
          } else {
            return new Date(this.valueOf() + this.utcOffset() * 60 * 1e3).toISOString().replace("Z", formatMoment(m, "Z"));
          }
        }
        return formatMoment(
          m,
          utc ? "YYYY-MM-DD[T]HH:mm:ss.SSS[Z]" : "YYYY-MM-DD[T]HH:mm:ss.SSSZ"
        );
      }
      function inspect() {
        if (!this.isValid()) {
          return "moment.invalid(/* " + this._i + " */)";
        }
        var func = "moment", zone = "", prefix, year, datetime, suffix;
        if (!this.isLocal()) {
          func = this.utcOffset() === 0 ? "moment.utc" : "moment.parseZone";
          zone = "Z";
        }
        prefix = "[" + func + '("]';
        year = 0 <= this.year() && this.year() <= 9999 ? "YYYY" : "YYYYYY";
        datetime = "-MM-DD[T]HH:mm:ss.SSS";
        suffix = zone + '[")]';
        return this.format(prefix + year + datetime + suffix);
      }
      function format(inputString) {
        if (!inputString) {
          inputString = this.isUtc() ? hooks.defaultFormatUtc : hooks.defaultFormat;
        }
        var output = formatMoment(this, inputString);
        return this.localeData().postformat(output);
      }
      function from(time, withoutSuffix) {
        if (this.isValid() && (isMoment(time) && time.isValid() || createLocal(time).isValid())) {
          return createDuration({ to: this, from: time }).locale(this.locale()).humanize(!withoutSuffix);
        } else {
          return this.localeData().invalidDate();
        }
      }
      function fromNow(withoutSuffix) {
        return this.from(createLocal(), withoutSuffix);
      }
      function to(time, withoutSuffix) {
        if (this.isValid() && (isMoment(time) && time.isValid() || createLocal(time).isValid())) {
          return createDuration({ from: this, to: time }).locale(this.locale()).humanize(!withoutSuffix);
        } else {
          return this.localeData().invalidDate();
        }
      }
      function toNow(withoutSuffix) {
        return this.to(createLocal(), withoutSuffix);
      }
      function locale(key) {
        var newLocaleData;
        if (key === void 0) {
          return this._locale._abbr;
        } else {
          newLocaleData = getLocale(key);
          if (newLocaleData != null) {
            this._locale = newLocaleData;
          }
          return this;
        }
      }
      var lang = deprecate(
        "moment().lang() is deprecated. Instead, use moment().localeData() to get the language configuration. Use moment().locale() to change languages.",
        function(key) {
          if (key === void 0) {
            return this.localeData();
          } else {
            return this.locale(key);
          }
        }
      );
      function localeData() {
        return this._locale;
      }
      var MS_PER_SECOND = 1e3, MS_PER_MINUTE = 60 * MS_PER_SECOND, MS_PER_HOUR = 60 * MS_PER_MINUTE, MS_PER_400_YEARS = (365 * 400 + 97) * 24 * MS_PER_HOUR;
      function mod(dividend, divisor) {
        return (dividend % divisor + divisor) % divisor;
      }
      function localStartOfDate(y, m, d) {
        if (y < 100 && y >= 0) {
          return new Date(y + 400, m, d) - MS_PER_400_YEARS;
        } else {
          return new Date(y, m, d).valueOf();
        }
      }
      function utcStartOfDate(y, m, d) {
        if (y < 100 && y >= 0) {
          return Date.UTC(y + 400, m, d) - MS_PER_400_YEARS;
        } else {
          return Date.UTC(y, m, d);
        }
      }
      function startOf(units) {
        var time, startOfDate;
        units = normalizeUnits(units);
        if (units === void 0 || units === "millisecond" || !this.isValid()) {
          return this;
        }
        startOfDate = this._isUTC ? utcStartOfDate : localStartOfDate;
        switch (units) {
          case "year":
            time = startOfDate(this.year(), 0, 1);
            break;
          case "quarter":
            time = startOfDate(
              this.year(),
              this.month() - this.month() % 3,
              1
            );
            break;
          case "month":
            time = startOfDate(this.year(), this.month(), 1);
            break;
          case "week":
            time = startOfDate(
              this.year(),
              this.month(),
              this.date() - this.weekday()
            );
            break;
          case "isoWeek":
            time = startOfDate(
              this.year(),
              this.month(),
              this.date() - (this.isoWeekday() - 1)
            );
            break;
          case "day":
          case "date":
            time = startOfDate(this.year(), this.month(), this.date());
            break;
          case "hour":
            time = this._d.valueOf();
            time -= mod(
              time + (this._isUTC ? 0 : this.utcOffset() * MS_PER_MINUTE),
              MS_PER_HOUR
            );
            break;
          case "minute":
            time = this._d.valueOf();
            time -= mod(time, MS_PER_MINUTE);
            break;
          case "second":
            time = this._d.valueOf();
            time -= mod(time, MS_PER_SECOND);
            break;
        }
        this._d.setTime(time);
        hooks.updateOffset(this, true);
        return this;
      }
      function endOf(units) {
        var time, startOfDate;
        units = normalizeUnits(units);
        if (units === void 0 || units === "millisecond" || !this.isValid()) {
          return this;
        }
        startOfDate = this._isUTC ? utcStartOfDate : localStartOfDate;
        switch (units) {
          case "year":
            time = startOfDate(this.year() + 1, 0, 1) - 1;
            break;
          case "quarter":
            time = startOfDate(
              this.year(),
              this.month() - this.month() % 3 + 3,
              1
            ) - 1;
            break;
          case "month":
            time = startOfDate(this.year(), this.month() + 1, 1) - 1;
            break;
          case "week":
            time = startOfDate(
              this.year(),
              this.month(),
              this.date() - this.weekday() + 7
            ) - 1;
            break;
          case "isoWeek":
            time = startOfDate(
              this.year(),
              this.month(),
              this.date() - (this.isoWeekday() - 1) + 7
            ) - 1;
            break;
          case "day":
          case "date":
            time = startOfDate(this.year(), this.month(), this.date() + 1) - 1;
            break;
          case "hour":
            time = this._d.valueOf();
            time += MS_PER_HOUR - mod(
              time + (this._isUTC ? 0 : this.utcOffset() * MS_PER_MINUTE),
              MS_PER_HOUR
            ) - 1;
            break;
          case "minute":
            time = this._d.valueOf();
            time += MS_PER_MINUTE - mod(time, MS_PER_MINUTE) - 1;
            break;
          case "second":
            time = this._d.valueOf();
            time += MS_PER_SECOND - mod(time, MS_PER_SECOND) - 1;
            break;
        }
        this._d.setTime(time);
        hooks.updateOffset(this, true);
        return this;
      }
      function valueOf$1() {
        return this._d.valueOf() - (this._offset || 0) * 6e4;
      }
      function unix() {
        return Math.floor(this.valueOf() / 1e3);
      }
      function toDate() {
        return new Date(this.valueOf());
      }
      function toArray() {
        var m = this;
        return [
          m.year(),
          m.month(),
          m.date(),
          m.hour(),
          m.minute(),
          m.second(),
          m.millisecond()
        ];
      }
      function toObject() {
        var m = this;
        return {
          years: m.year(),
          months: m.month(),
          date: m.date(),
          hours: m.hours(),
          minutes: m.minutes(),
          seconds: m.seconds(),
          milliseconds: m.milliseconds()
        };
      }
      function toJSON() {
        return this.isValid() ? this.toISOString() : null;
      }
      function isValid() {
        return isValid$2(this);
      }
      function parsingFlags() {
        return extend({}, getParsingFlags(this));
      }
      function invalidAt() {
        return getParsingFlags(this).overflow;
      }
      function creationData() {
        return {
          input: this._i,
          format: this._f,
          locale: this._locale,
          isUTC: this._isUTC,
          strict: this._strict
        };
      }
      addFormatToken("N", 0, 0, "eraAbbr");
      addFormatToken("NN", 0, 0, "eraAbbr");
      addFormatToken("NNN", 0, 0, "eraAbbr");
      addFormatToken("NNNN", 0, 0, "eraName");
      addFormatToken("NNNNN", 0, 0, "eraNarrow");
      addFormatToken("y", ["y", 1], "yo", "eraYear");
      addFormatToken("y", ["yy", 2], 0, "eraYear");
      addFormatToken("y", ["yyy", 3], 0, "eraYear");
      addFormatToken("y", ["yyyy", 4], 0, "eraYear");
      addRegexToken("N", matchEraAbbr);
      addRegexToken("NN", matchEraAbbr);
      addRegexToken("NNN", matchEraAbbr);
      addRegexToken("NNNN", matchEraName);
      addRegexToken("NNNNN", matchEraNarrow);
      addParseToken(
        ["N", "NN", "NNN", "NNNN", "NNNNN"],
        function(input, array, config, token2) {
          var era = config._locale.erasParse(input, token2, config._strict);
          if (era) {
            getParsingFlags(config).era = era;
          } else {
            getParsingFlags(config).invalidEra = input;
          }
        }
      );
      addRegexToken("y", matchUnsigned);
      addRegexToken("yy", matchUnsigned);
      addRegexToken("yyy", matchUnsigned);
      addRegexToken("yyyy", matchUnsigned);
      addRegexToken("yo", matchEraYearOrdinal);
      addParseToken(["y", "yy", "yyy", "yyyy"], YEAR);
      addParseToken(["yo"], function(input, array, config, token2) {
        var match;
        if (config._locale._eraYearOrdinalRegex) {
          match = input.match(config._locale._eraYearOrdinalRegex);
        }
        if (config._locale.eraYearOrdinalParse) {
          array[YEAR] = config._locale.eraYearOrdinalParse(input, match);
        } else {
          array[YEAR] = parseInt(input, 10);
        }
      });
      function localeEras(m, format2) {
        var i, l, date, eras = this._eras || getLocale("en")._eras;
        for (i = 0, l = eras.length; i < l; ++i) {
          switch (typeof eras[i].since) {
            case "string":
              date = hooks(eras[i].since).startOf("day");
              eras[i].since = date.valueOf();
              break;
          }
          switch (typeof eras[i].until) {
            case "undefined":
              eras[i].until = Infinity;
              break;
            case "string":
              date = hooks(eras[i].until).startOf("day").valueOf();
              eras[i].until = date.valueOf();
              break;
          }
        }
        return eras;
      }
      function localeErasParse(eraName, format2, strict) {
        var i, l, eras = this.eras(), name, abbr, narrow;
        eraName = eraName.toUpperCase();
        for (i = 0, l = eras.length; i < l; ++i) {
          name = eras[i].name.toUpperCase();
          abbr = eras[i].abbr.toUpperCase();
          narrow = eras[i].narrow.toUpperCase();
          if (strict) {
            switch (format2) {
              case "N":
              case "NN":
              case "NNN":
                if (abbr === eraName) {
                  return eras[i];
                }
                break;
              case "NNNN":
                if (name === eraName) {
                  return eras[i];
                }
                break;
              case "NNNNN":
                if (narrow === eraName) {
                  return eras[i];
                }
                break;
            }
          } else if ([name, abbr, narrow].indexOf(eraName) >= 0) {
            return eras[i];
          }
        }
      }
      function localeErasConvertYear(era, year) {
        var dir = era.since <= era.until ? 1 : -1;
        if (year === void 0) {
          return hooks(era.since).year();
        } else {
          return hooks(era.since).year() + (year - era.offset) * dir;
        }
      }
      function getEraName() {
        var i, l, val, eras = this.localeData().eras();
        for (i = 0, l = eras.length; i < l; ++i) {
          val = this.clone().startOf("day").valueOf();
          if (eras[i].since <= val && val <= eras[i].until) {
            return eras[i].name;
          }
          if (eras[i].until <= val && val <= eras[i].since) {
            return eras[i].name;
          }
        }
        return "";
      }
      function getEraNarrow() {
        var i, l, val, eras = this.localeData().eras();
        for (i = 0, l = eras.length; i < l; ++i) {
          val = this.clone().startOf("day").valueOf();
          if (eras[i].since <= val && val <= eras[i].until) {
            return eras[i].narrow;
          }
          if (eras[i].until <= val && val <= eras[i].since) {
            return eras[i].narrow;
          }
        }
        return "";
      }
      function getEraAbbr() {
        var i, l, val, eras = this.localeData().eras();
        for (i = 0, l = eras.length; i < l; ++i) {
          val = this.clone().startOf("day").valueOf();
          if (eras[i].since <= val && val <= eras[i].until) {
            return eras[i].abbr;
          }
          if (eras[i].until <= val && val <= eras[i].since) {
            return eras[i].abbr;
          }
        }
        return "";
      }
      function getEraYear() {
        var i, l, dir, val, eras = this.localeData().eras();
        for (i = 0, l = eras.length; i < l; ++i) {
          dir = eras[i].since <= eras[i].until ? 1 : -1;
          val = this.clone().startOf("day").valueOf();
          if (eras[i].since <= val && val <= eras[i].until || eras[i].until <= val && val <= eras[i].since) {
            return (this.year() - hooks(eras[i].since).year()) * dir + eras[i].offset;
          }
        }
        return this.year();
      }
      function erasNameRegex(isStrict) {
        if (!hasOwnProp(this, "_erasNameRegex")) {
          computeErasParse.call(this);
        }
        return isStrict ? this._erasNameRegex : this._erasRegex;
      }
      function erasAbbrRegex(isStrict) {
        if (!hasOwnProp(this, "_erasAbbrRegex")) {
          computeErasParse.call(this);
        }
        return isStrict ? this._erasAbbrRegex : this._erasRegex;
      }
      function erasNarrowRegex(isStrict) {
        if (!hasOwnProp(this, "_erasNarrowRegex")) {
          computeErasParse.call(this);
        }
        return isStrict ? this._erasNarrowRegex : this._erasRegex;
      }
      function matchEraAbbr(isStrict, locale2) {
        return locale2.erasAbbrRegex(isStrict);
      }
      function matchEraName(isStrict, locale2) {
        return locale2.erasNameRegex(isStrict);
      }
      function matchEraNarrow(isStrict, locale2) {
        return locale2.erasNarrowRegex(isStrict);
      }
      function matchEraYearOrdinal(isStrict, locale2) {
        return locale2._eraYearOrdinalRegex || matchUnsigned;
      }
      function computeErasParse() {
        var abbrPieces = [], namePieces = [], narrowPieces = [], mixedPieces = [], i, l, erasName, erasAbbr, erasNarrow, eras = this.eras();
        for (i = 0, l = eras.length; i < l; ++i) {
          erasName = regexEscape(eras[i].name);
          erasAbbr = regexEscape(eras[i].abbr);
          erasNarrow = regexEscape(eras[i].narrow);
          namePieces.push(erasName);
          abbrPieces.push(erasAbbr);
          narrowPieces.push(erasNarrow);
          mixedPieces.push(erasName);
          mixedPieces.push(erasAbbr);
          mixedPieces.push(erasNarrow);
        }
        this._erasRegex = new RegExp("^(" + mixedPieces.join("|") + ")", "i");
        this._erasNameRegex = new RegExp("^(" + namePieces.join("|") + ")", "i");
        this._erasAbbrRegex = new RegExp("^(" + abbrPieces.join("|") + ")", "i");
        this._erasNarrowRegex = new RegExp(
          "^(" + narrowPieces.join("|") + ")",
          "i"
        );
      }
      addFormatToken(0, ["gg", 2], 0, function() {
        return this.weekYear() % 100;
      });
      addFormatToken(0, ["GG", 2], 0, function() {
        return this.isoWeekYear() % 100;
      });
      function addWeekYearFormatToken(token2, getter) {
        addFormatToken(0, [token2, token2.length], 0, getter);
      }
      addWeekYearFormatToken("gggg", "weekYear");
      addWeekYearFormatToken("ggggg", "weekYear");
      addWeekYearFormatToken("GGGG", "isoWeekYear");
      addWeekYearFormatToken("GGGGG", "isoWeekYear");
      addRegexToken("G", matchSigned);
      addRegexToken("g", matchSigned);
      addRegexToken("GG", match1to2, match2);
      addRegexToken("gg", match1to2, match2);
      addRegexToken("GGGG", match1to4, match4);
      addRegexToken("gggg", match1to4, match4);
      addRegexToken("GGGGG", match1to6, match6);
      addRegexToken("ggggg", match1to6, match6);
      addWeekParseToken(
        ["gggg", "ggggg", "GGGG", "GGGGG"],
        function(input, week, config, token2) {
          week[token2.substr(0, 2)] = toInt(input);
        }
      );
      addWeekParseToken(["gg", "GG"], function(input, week, config, token2) {
        week[token2] = hooks.parseTwoDigitYear(input);
      });
      function getSetWeekYear(input) {
        return getSetWeekYearHelper.call(
          this,
          input,
          this.week(),
          this.weekday() + this.localeData()._week.dow,
          this.localeData()._week.dow,
          this.localeData()._week.doy
        );
      }
      function getSetISOWeekYear(input) {
        return getSetWeekYearHelper.call(
          this,
          input,
          this.isoWeek(),
          this.isoWeekday(),
          1,
          4
        );
      }
      function getISOWeeksInYear() {
        return weeksInYear(this.year(), 1, 4);
      }
      function getISOWeeksInISOWeekYear() {
        return weeksInYear(this.isoWeekYear(), 1, 4);
      }
      function getWeeksInYear() {
        var weekInfo = this.localeData()._week;
        return weeksInYear(this.year(), weekInfo.dow, weekInfo.doy);
      }
      function getWeeksInWeekYear() {
        var weekInfo = this.localeData()._week;
        return weeksInYear(this.weekYear(), weekInfo.dow, weekInfo.doy);
      }
      function getSetWeekYearHelper(input, week, weekday, dow, doy) {
        var weeksTarget;
        if (input == null) {
          return weekOfYear(this, dow, doy).year;
        } else {
          weeksTarget = weeksInYear(input, dow, doy);
          if (week > weeksTarget) {
            week = weeksTarget;
          }
          return setWeekAll.call(this, input, week, weekday, dow, doy);
        }
      }
      function setWeekAll(weekYear, week, weekday, dow, doy) {
        var dayOfYearData = dayOfYearFromWeeks(weekYear, week, weekday, dow, doy), date = createUTCDate(dayOfYearData.year, 0, dayOfYearData.dayOfYear);
        this.year(date.getUTCFullYear());
        this.month(date.getUTCMonth());
        this.date(date.getUTCDate());
        return this;
      }
      addFormatToken("Q", 0, "Qo", "quarter");
      addRegexToken("Q", match1);
      addParseToken("Q", function(input, array) {
        array[MONTH] = (toInt(input) - 1) * 3;
      });
      function getSetQuarter(input) {
        return input == null ? Math.ceil((this.month() + 1) / 3) : this.month((input - 1) * 3 + this.month() % 3);
      }
      addFormatToken("D", ["DD", 2], "Do", "date");
      addRegexToken("D", match1to2, match1to2NoLeadingZero);
      addRegexToken("DD", match1to2, match2);
      addRegexToken("Do", function(isStrict, locale2) {
        return isStrict ? locale2._dayOfMonthOrdinalParse || locale2._ordinalParse : locale2._dayOfMonthOrdinalParseLenient;
      });
      addParseToken(["D", "DD"], DATE);
      addParseToken("Do", function(input, array) {
        array[DATE] = toInt(input.match(match1to2)[0]);
      });
      var getSetDayOfMonth = makeGetSet("Date", true);
      addFormatToken("DDD", ["DDDD", 3], "DDDo", "dayOfYear");
      addRegexToken("DDD", match1to3);
      addRegexToken("DDDD", match3);
      addParseToken(["DDD", "DDDD"], function(input, array, config) {
        config._dayOfYear = toInt(input);
      });
      function getSetDayOfYear(input) {
        var dayOfYear = Math.round(
          (this.clone().startOf("day") - this.clone().startOf("year")) / 864e5
        ) + 1;
        return input == null ? dayOfYear : this.add(input - dayOfYear, "d");
      }
      addFormatToken("m", ["mm", 2], 0, "minute");
      addRegexToken("m", match1to2, match1to2HasZero);
      addRegexToken("mm", match1to2, match2);
      addParseToken(["m", "mm"], MINUTE);
      var getSetMinute = makeGetSet("Minutes", false);
      addFormatToken("s", ["ss", 2], 0, "second");
      addRegexToken("s", match1to2, match1to2HasZero);
      addRegexToken("ss", match1to2, match2);
      addParseToken(["s", "ss"], SECOND);
      var getSetSecond = makeGetSet("Seconds", false);
      addFormatToken("S", 0, 0, function() {
        return ~~(this.millisecond() / 100);
      });
      addFormatToken(0, ["SS", 2], 0, function() {
        return ~~(this.millisecond() / 10);
      });
      addFormatToken(0, ["SSS", 3], 0, "millisecond");
      addFormatToken(0, ["SSSS", 4], 0, function() {
        return this.millisecond() * 10;
      });
      addFormatToken(0, ["SSSSS", 5], 0, function() {
        return this.millisecond() * 100;
      });
      addFormatToken(0, ["SSSSSS", 6], 0, function() {
        return this.millisecond() * 1e3;
      });
      addFormatToken(0, ["SSSSSSS", 7], 0, function() {
        return this.millisecond() * 1e4;
      });
      addFormatToken(0, ["SSSSSSSS", 8], 0, function() {
        return this.millisecond() * 1e5;
      });
      addFormatToken(0, ["SSSSSSSSS", 9], 0, function() {
        return this.millisecond() * 1e6;
      });
      addRegexToken("S", match1to3, match1);
      addRegexToken("SS", match1to3, match2);
      addRegexToken("SSS", match1to3, match3);
      var token, getSetMillisecond;
      for (token = "SSSS"; token.length <= 9; token += "S") {
        addRegexToken(token, matchUnsigned);
      }
      function parseMs(input, array) {
        array[MILLISECOND] = toInt(("0." + input) * 1e3);
      }
      for (token = "S"; token.length <= 9; token += "S") {
        addParseToken(token, parseMs);
      }
      getSetMillisecond = makeGetSet("Milliseconds", false);
      addFormatToken("z", 0, 0, "zoneAbbr");
      addFormatToken("zz", 0, 0, "zoneName");
      function getZoneAbbr() {
        return this._isUTC ? "UTC" : "";
      }
      function getZoneName() {
        return this._isUTC ? "Coordinated Universal Time" : "";
      }
      var proto$2 = Moment.prototype;
      proto$2.add = add$1;
      proto$2.calendar = calendar;
      proto$2.clone = clone$1;
      proto$2.diff = diff;
      proto$2.endOf = endOf;
      proto$2.format = format;
      proto$2.from = from;
      proto$2.fromNow = fromNow;
      proto$2.to = to;
      proto$2.toNow = toNow;
      proto$2.get = stringGet;
      proto$2.invalidAt = invalidAt;
      proto$2.isAfter = isAfter;
      proto$2.isBefore = isBefore;
      proto$2.isBetween = isBetween;
      proto$2.isSame = isSame;
      proto$2.isSameOrAfter = isSameOrAfter;
      proto$2.isSameOrBefore = isSameOrBefore;
      proto$2.isValid = isValid;
      proto$2.lang = lang;
      proto$2.locale = locale;
      proto$2.localeData = localeData;
      proto$2.max = prototypeMax;
      proto$2.min = prototypeMin;
      proto$2.parsingFlags = parsingFlags;
      proto$2.set = stringSet;
      proto$2.startOf = startOf;
      proto$2.subtract = subtract$1;
      proto$2.toArray = toArray;
      proto$2.toObject = toObject;
      proto$2.toDate = toDate;
      proto$2.toISOString = toISOString$1;
      proto$2.inspect = inspect;
      if (typeof Symbol !== "undefined" && Symbol.for != null) {
        proto$2[/* @__PURE__ */ Symbol.for("nodejs.util.inspect.custom")] = function() {
          return "Moment<" + this.format() + ">";
        };
      }
      proto$2.toJSON = toJSON;
      proto$2.toString = toString;
      proto$2.unix = unix;
      proto$2.valueOf = valueOf$1;
      proto$2.creationData = creationData;
      proto$2.eraName = getEraName;
      proto$2.eraNarrow = getEraNarrow;
      proto$2.eraAbbr = getEraAbbr;
      proto$2.eraYear = getEraYear;
      proto$2.year = getSetYear;
      proto$2.isLeapYear = getIsLeapYear;
      proto$2.weekYear = getSetWeekYear;
      proto$2.isoWeekYear = getSetISOWeekYear;
      proto$2.quarter = proto$2.quarters = getSetQuarter;
      proto$2.month = getSetMonth;
      proto$2.daysInMonth = getDaysInMonth;
      proto$2.week = proto$2.weeks = getSetWeek;
      proto$2.isoWeek = proto$2.isoWeeks = getSetISOWeek;
      proto$2.weeksInYear = getWeeksInYear;
      proto$2.weeksInWeekYear = getWeeksInWeekYear;
      proto$2.isoWeeksInYear = getISOWeeksInYear;
      proto$2.isoWeeksInISOWeekYear = getISOWeeksInISOWeekYear;
      proto$2.date = getSetDayOfMonth;
      proto$2.day = proto$2.days = getSetDayOfWeek;
      proto$2.weekday = getSetLocaleDayOfWeek;
      proto$2.isoWeekday = getSetISODayOfWeek;
      proto$2.dayOfYear = getSetDayOfYear;
      proto$2.hour = proto$2.hours = getSetHour;
      proto$2.minute = proto$2.minutes = getSetMinute;
      proto$2.second = proto$2.seconds = getSetSecond;
      proto$2.millisecond = proto$2.milliseconds = getSetMillisecond;
      proto$2.utcOffset = getSetOffset;
      proto$2.utc = setOffsetToUTC;
      proto$2.local = setOffsetToLocal;
      proto$2.parseZone = setOffsetToParsedOffset;
      proto$2.hasAlignedHourOffset = hasAlignedHourOffset;
      proto$2.isDST = isDaylightSavingTime;
      proto$2.isLocal = isLocal;
      proto$2.isUtcOffset = isUtcOffset;
      proto$2.isUtc = isUtc;
      proto$2.isUTC = isUtc;
      proto$2.zoneAbbr = getZoneAbbr;
      proto$2.zoneName = getZoneName;
      proto$2.dates = deprecate(
        "dates accessor is deprecated. Use date instead.",
        getSetDayOfMonth
      );
      proto$2.months = deprecate(
        "months accessor is deprecated. Use month instead",
        getSetMonth
      );
      proto$2.years = deprecate(
        "years accessor is deprecated. Use year instead",
        getSetYear
      );
      proto$2.zone = deprecate(
        "moment().zone is deprecated, use moment().utcOffset instead. http://momentjs.com/guides/#/warnings/zone/",
        getSetZone
      );
      proto$2.isDSTShifted = deprecate(
        "isDSTShifted is deprecated. See http://momentjs.com/guides/#/warnings/dst-shifted/ for more information",
        isDaylightSavingTimeShifted
      );
      function createUnix(input) {
        return createLocal(input * 1e3);
      }
      function createInZone() {
        return createLocal.apply(null, arguments).parseZone();
      }
      function preParsePostFormat(string) {
        return string;
      }
      var proto$1 = Locale.prototype;
      proto$1.calendar = calendar$1;
      proto$1.longDateFormat = longDateFormat;
      proto$1.invalidDate = invalidDate;
      proto$1.ordinal = ordinal;
      proto$1.preparse = preParsePostFormat;
      proto$1.postformat = preParsePostFormat;
      proto$1.relativeTime = relativeTime$1;
      proto$1.pastFuture = pastFuture;
      proto$1.set = set;
      proto$1.eras = localeEras;
      proto$1.erasParse = localeErasParse;
      proto$1.erasConvertYear = localeErasConvertYear;
      proto$1.erasAbbrRegex = erasAbbrRegex;
      proto$1.erasNameRegex = erasNameRegex;
      proto$1.erasNarrowRegex = erasNarrowRegex;
      proto$1.months = localeMonths;
      proto$1.monthsShort = localeMonthsShort;
      proto$1.monthsParse = localeMonthsParse;
      proto$1.monthsRegex = monthsRegex;
      proto$1.monthsShortRegex = monthsShortRegex;
      proto$1.week = localeWeek;
      proto$1.firstDayOfYear = localeFirstDayOfYear;
      proto$1.firstDayOfWeek = localeFirstDayOfWeek;
      proto$1.weekdays = localeWeekdays;
      proto$1.weekdaysMin = localeWeekdaysMin;
      proto$1.weekdaysShort = localeWeekdaysShort;
      proto$1.weekdaysParse = localeWeekdaysParse;
      proto$1.weekdaysRegex = weekdaysRegex;
      proto$1.weekdaysShortRegex = weekdaysShortRegex;
      proto$1.weekdaysMinRegex = weekdaysMinRegex;
      proto$1.isPM = localeIsPM;
      proto$1.meridiem = localeMeridiem;
      function get$1(format2, index, field, setter) {
        var locale2 = getLocale(), utc = createUTC().set(setter, index);
        return locale2[field](utc, format2);
      }
      function listMonthsImpl(format2, index, field) {
        if (isNumber(format2)) {
          index = format2;
          format2 = void 0;
        }
        format2 = format2 || "";
        if (index != null) {
          return get$1(format2, index, field, "month");
        }
        var i, out = [];
        for (i = 0; i < 12; i++) {
          out[i] = get$1(format2, i, field, "month");
        }
        return out;
      }
      function listWeekdaysImpl(localeSorted, format2, index, field) {
        if (typeof localeSorted === "boolean") {
          if (isNumber(format2)) {
            index = format2;
            format2 = void 0;
          }
          format2 = format2 || "";
        } else {
          format2 = localeSorted;
          index = format2;
          localeSorted = false;
          if (isNumber(format2)) {
            index = format2;
            format2 = void 0;
          }
          format2 = format2 || "";
        }
        var locale2 = getLocale(), shift = localeSorted ? locale2._week.dow : 0, i, out = [];
        if (index != null) {
          return get$1(format2, (index + shift) % 7, field, "day");
        }
        for (i = 0; i < 7; i++) {
          out[i] = get$1(format2, (i + shift) % 7, field, "day");
        }
        return out;
      }
      function listMonths(format2, index) {
        return listMonthsImpl(format2, index, "months");
      }
      function listMonthsShort(format2, index) {
        return listMonthsImpl(format2, index, "monthsShort");
      }
      function listWeekdays(localeSorted, format2, index) {
        return listWeekdaysImpl(localeSorted, format2, index, "weekdays");
      }
      function listWeekdaysShort(localeSorted, format2, index) {
        return listWeekdaysImpl(localeSorted, format2, index, "weekdaysShort");
      }
      function listWeekdaysMin(localeSorted, format2, index) {
        return listWeekdaysImpl(localeSorted, format2, index, "weekdaysMin");
      }
      getSetGlobalLocale("en", {
        eras: [
          {
            since: "0001-01-01",
            until: Infinity,
            offset: 1,
            name: "Anno Domini",
            narrow: "AD",
            abbr: "AD"
          },
          {
            since: "0000-12-31",
            until: -Infinity,
            offset: 1,
            name: "Before Christ",
            narrow: "BC",
            abbr: "BC"
          }
        ],
        dayOfMonthOrdinalParse: /\d{1,2}(th|st|nd|rd)/,
        ordinal: function(number) {
          var b = number % 10, output = toInt(number % 100 / 10) === 1 ? "th" : b === 1 ? "st" : b === 2 ? "nd" : b === 3 ? "rd" : "th";
          return number + output;
        }
      });
      hooks.lang = deprecate(
        "moment.lang is deprecated. Use moment.locale instead.",
        getSetGlobalLocale
      );
      hooks.langData = deprecate(
        "moment.langData is deprecated. Use moment.localeData instead.",
        getLocale
      );
      var mathAbs = Math.abs;
      function abs$1() {
        var data = this._data;
        this._milliseconds = mathAbs(this._milliseconds);
        this._days = mathAbs(this._days);
        this._months = mathAbs(this._months);
        data.milliseconds = mathAbs(data.milliseconds);
        data.seconds = mathAbs(data.seconds);
        data.minutes = mathAbs(data.minutes);
        data.hours = mathAbs(data.hours);
        data.months = mathAbs(data.months);
        data.years = mathAbs(data.years);
        return this;
      }
      function addSubtract(duration, input, value, direction) {
        var other = createDuration(input, value);
        duration._milliseconds += direction * other._milliseconds;
        duration._days += direction * other._days;
        duration._months += direction * other._months;
        return duration._bubble();
      }
      function add(input, value) {
        return addSubtract(this, input, value, 1);
      }
      function subtract(input, value) {
        return addSubtract(this, input, value, -1);
      }
      function absCeil(number) {
        if (number < 0) {
          return Math.floor(number);
        } else {
          return Math.ceil(number);
        }
      }
      function bubble() {
        var milliseconds2 = this._milliseconds, days2 = this._days, months2 = this._months, data = this._data, seconds2, minutes2, hours2, years2, monthsFromDays;
        if (!(milliseconds2 >= 0 && days2 >= 0 && months2 >= 0 || milliseconds2 <= 0 && days2 <= 0 && months2 <= 0)) {
          milliseconds2 += absCeil(monthsToDays(months2) + days2) * 864e5;
          days2 = 0;
          months2 = 0;
        }
        data.milliseconds = milliseconds2 % 1e3;
        seconds2 = absFloor(milliseconds2 / 1e3);
        data.seconds = seconds2 % 60;
        minutes2 = absFloor(seconds2 / 60);
        data.minutes = minutes2 % 60;
        hours2 = absFloor(minutes2 / 60);
        data.hours = hours2 % 24;
        days2 += absFloor(hours2 / 24);
        monthsFromDays = absFloor(daysToMonths(days2));
        months2 += monthsFromDays;
        days2 -= absCeil(monthsToDays(monthsFromDays));
        years2 = absFloor(months2 / 12);
        months2 %= 12;
        data.days = days2;
        data.months = months2;
        data.years = years2;
        return this;
      }
      function daysToMonths(days2) {
        return days2 * 4800 / 146097;
      }
      function monthsToDays(months2) {
        return months2 * 146097 / 4800;
      }
      function as(units) {
        if (!this.isValid()) {
          return NaN;
        }
        var days2, months2, milliseconds2 = this._milliseconds;
        units = normalizeUnits(units);
        if (units === "month" || units === "quarter" || units === "year") {
          days2 = this._days + milliseconds2 / 864e5;
          months2 = this._months + daysToMonths(days2);
          switch (units) {
            case "month":
              return months2;
            case "quarter":
              return months2 / 3;
            case "year":
              return months2 / 12;
          }
        } else {
          days2 = this._days + Math.round(monthsToDays(this._months));
          switch (units) {
            case "week":
              return days2 / 7 + milliseconds2 / 6048e5;
            case "day":
              return days2 + milliseconds2 / 864e5;
            case "hour":
              return days2 * 24 + milliseconds2 / 36e5;
            case "minute":
              return days2 * 1440 + milliseconds2 / 6e4;
            case "second":
              return days2 * 86400 + milliseconds2 / 1e3;
            // Math.floor prevents floating point math errors here
            case "millisecond":
              return Math.floor(days2 * 864e5) + milliseconds2;
            default:
              throw new Error("Unknown unit " + units);
          }
        }
      }
      function makeAs(alias) {
        return function() {
          return this.as(alias);
        };
      }
      var asMilliseconds = makeAs("ms"), asSeconds = makeAs("s"), asMinutes = makeAs("m"), asHours = makeAs("h"), asDays = makeAs("d"), asWeeks = makeAs("w"), asMonths = makeAs("M"), asQuarters = makeAs("Q"), asYears = makeAs("y"), valueOf = asMilliseconds;
      function clone() {
        return createDuration(this);
      }
      function get(units) {
        units = normalizeUnits(units);
        return this.isValid() ? this[units + "s"]() : NaN;
      }
      function makeGetter(name) {
        return function() {
          return this.isValid() ? this._data[name] : NaN;
        };
      }
      var milliseconds = makeGetter("milliseconds"), seconds = makeGetter("seconds"), minutes = makeGetter("minutes"), hours = makeGetter("hours"), days = makeGetter("days"), months = makeGetter("months"), years = makeGetter("years");
      function weeks() {
        return absFloor(this.days() / 7);
      }
      var round = Math.round, thresholds = {
        ss: 44,
        // a few seconds to seconds
        s: 45,
        // seconds to minute
        m: 45,
        // minutes to hour
        h: 22,
        // hours to day
        d: 26,
        // days to month/week
        w: null,
        // weeks to month
        M: 11
        // months to year
      };
      function substituteTimeAgo(string, number, withoutSuffix, isFuture, locale2) {
        return relativeTimeWithoutPostformat.call(
          locale2,
          number || 1,
          !!withoutSuffix,
          string,
          isFuture
        );
      }
      function relativeTime(posNegDuration, withoutSuffix, thresholds2, locale2) {
        var duration = createDuration(posNegDuration).abs(), seconds2 = round(duration.as("s")), minutes2 = round(duration.as("m")), hours2 = round(duration.as("h")), days2 = round(duration.as("d")), months2 = round(duration.as("M")), weeks2 = round(duration.as("w")), years2 = round(duration.as("y")), a = seconds2 <= thresholds2.ss && ["s", seconds2] || seconds2 < thresholds2.s && ["ss", seconds2] || minutes2 <= 1 && ["m"] || minutes2 < thresholds2.m && ["mm", minutes2] || hours2 <= 1 && ["h"] || hours2 < thresholds2.h && ["hh", hours2] || days2 <= 1 && ["d"] || days2 < thresholds2.d && ["dd", days2];
        if (thresholds2.w != null) {
          a = a || weeks2 <= 1 && ["w"] || weeks2 < thresholds2.w && ["ww", weeks2];
        }
        a = a || months2 <= 1 && ["M"] || months2 < thresholds2.M && ["MM", months2] || years2 <= 1 && ["y"] || ["yy", years2];
        a[2] = withoutSuffix;
        a[3] = +posNegDuration > 0;
        a[4] = locale2;
        return substituteTimeAgo.apply(null, a);
      }
      function getSetRelativeTimeRounding(roundingFunction) {
        if (roundingFunction === void 0) {
          return round;
        }
        if (typeof roundingFunction === "function") {
          round = roundingFunction;
          return true;
        }
        return false;
      }
      function getSetRelativeTimeThreshold(threshold, limit) {
        if (thresholds[threshold] === void 0) {
          return false;
        }
        if (limit === void 0) {
          return thresholds[threshold];
        }
        thresholds[threshold] = limit;
        if (threshold === "s") {
          thresholds.ss = limit - 1;
        }
        return true;
      }
      function humanize(argWithSuffix, argThresholds) {
        if (!this.isValid()) {
          return this.localeData().invalidDate();
        }
        var withSuffix = false, th = thresholds, locale2, output;
        if (typeof argWithSuffix === "object") {
          argThresholds = argWithSuffix;
          argWithSuffix = false;
        }
        if (typeof argWithSuffix === "boolean") {
          withSuffix = argWithSuffix;
        }
        if (typeof argThresholds === "object") {
          th = extend(extend({}, thresholds), argThresholds || {});
          if (argThresholds.s != null && argThresholds.ss == null) {
            th.ss = argThresholds.s - 1;
          }
        }
        locale2 = this.localeData();
        output = relativeTime(this, !withSuffix, th, locale2);
        if (withSuffix) {
          output = pastFutureWithoutPostformat.call(locale2, +this, output);
        }
        return locale2.postformat(output);
      }
      var abs = Math.abs;
      function sign(x) {
        return (x > 0) - (x < 0) || +x;
      }
      function toISOString() {
        if (!this.isValid()) {
          return this.localeData().invalidDate();
        }
        var seconds2 = abs(this._milliseconds) / 1e3, days2 = abs(this._days), months2 = abs(this._months), minutes2, hours2, years2, s, total = this.asSeconds(), totalSign, ymSign, daysSign, hmsSign;
        if (!total) {
          return "P0D";
        }
        minutes2 = absFloor(seconds2 / 60);
        hours2 = absFloor(minutes2 / 60);
        seconds2 %= 60;
        minutes2 %= 60;
        years2 = absFloor(months2 / 12);
        months2 %= 12;
        s = seconds2 ? seconds2.toFixed(3).replace(/\.?0+$/, "") : "";
        totalSign = total < 0 ? "-" : "";
        ymSign = sign(this._months) !== sign(total) ? "-" : "";
        daysSign = sign(this._days) !== sign(total) ? "-" : "";
        hmsSign = sign(this._milliseconds) !== sign(total) ? "-" : "";
        return totalSign + "P" + (years2 ? ymSign + years2 + "Y" : "") + (months2 ? ymSign + months2 + "M" : "") + (days2 ? daysSign + days2 + "D" : "") + (hours2 || minutes2 || seconds2 ? "T" : "") + (hours2 ? hmsSign + hours2 + "H" : "") + (minutes2 ? hmsSign + minutes2 + "M" : "") + (seconds2 ? hmsSign + s + "S" : "");
      }
      var proto = Duration.prototype;
      proto.isValid = isValid$1;
      proto.abs = abs$1;
      proto.add = add;
      proto.subtract = subtract;
      proto.as = as;
      proto.asMilliseconds = asMilliseconds;
      proto.asSeconds = asSeconds;
      proto.asMinutes = asMinutes;
      proto.asHours = asHours;
      proto.asDays = asDays;
      proto.asWeeks = asWeeks;
      proto.asMonths = asMonths;
      proto.asQuarters = asQuarters;
      proto.asYears = asYears;
      proto.valueOf = valueOf;
      proto._bubble = bubble;
      proto.clone = clone;
      proto.get = get;
      proto.milliseconds = milliseconds;
      proto.seconds = seconds;
      proto.minutes = minutes;
      proto.hours = hours;
      proto.days = days;
      proto.weeks = weeks;
      proto.months = months;
      proto.years = years;
      proto.humanize = humanize;
      proto.toISOString = toISOString;
      proto.toString = toISOString;
      proto.toJSON = toISOString;
      proto.locale = locale;
      proto.localeData = localeData;
      proto.toIsoString = deprecate(
        "toIsoString() is deprecated. Please use toISOString() instead (notice the capitals)",
        toISOString
      );
      proto.lang = lang;
      addFormatToken("X", 0, 0, "unix");
      addFormatToken("x", 0, 0, "valueOf");
      addRegexToken("x", matchSigned);
      addRegexToken("X", matchTimestamp);
      addParseToken("X", function(input, array, config) {
        config._d = new Date(parseFloat(input) * 1e3);
      });
      addParseToken("x", function(input, array, config) {
        config._d = new Date(toInt(input));
      });
      hooks.version = "2.31.0";
      setHookCallback(createLocal);
      hooks.fn = proto$2;
      hooks.min = min;
      hooks.max = max;
      hooks.now = now;
      hooks.utc = createUTC;
      hooks.unix = createUnix;
      hooks.months = listMonths;
      hooks.isDate = isDate;
      hooks.locale = getSetGlobalLocale;
      hooks.invalid = createInvalid$1;
      hooks.duration = createDuration;
      hooks.isMoment = isMoment;
      hooks.weekdays = listWeekdays;
      hooks.parseZone = createInZone;
      hooks.localeData = getLocale;
      hooks.isDuration = isDuration;
      hooks.monthsShort = listMonthsShort;
      hooks.weekdaysMin = listWeekdaysMin;
      hooks.defineLocale = defineLocale;
      hooks.updateLocale = updateLocale;
      hooks.locales = listLocales;
      hooks.weekdaysShort = listWeekdaysShort;
      hooks.normalizeUnits = normalizeUnits;
      hooks.relativeTimeRounding = getSetRelativeTimeRounding;
      hooks.relativeTimeThreshold = getSetRelativeTimeThreshold;
      hooks.calendarFormat = getCalendarFormat;
      hooks.prototype = proto$2;
      hooks.HTML5_FMT = {
        DATETIME_LOCAL: "YYYY-MM-DDTHH:mm",
        // <input type="datetime-local" />
        DATETIME_LOCAL_SECONDS: "YYYY-MM-DDTHH:mm:ss",
        // <input type="datetime-local" step="1" />
        DATETIME_LOCAL_MS: "YYYY-MM-DDTHH:mm:ss.SSS",
        // <input type="datetime-local" step="0.001" />
        DATE: "YYYY-MM-DD",
        // <input type="date" />
        TIME: "HH:mm",
        // <input type="time" />
        TIME_SECONDS: "HH:mm:ss",
        // <input type="time" step="1" />
        TIME_MS: "HH:mm:ss.SSS",
        // <input type="time" step="0.001" />
        WEEK: "GGGG-[W]WW",
        // <input type="week" />
        MONTH: "YYYY-MM"
        // <input type="month" />
      };
      return hooks;
    }));
  }
});

// node_modules/file-stream-rotator/FileStreamRotator.js
var require_FileStreamRotator = __commonJS({
  "node_modules/file-stream-rotator/FileStreamRotator.js"(exports2, module2) {
    "use strict";
    var fs2 = require("fs");
    var path2 = require("path");
    var moment = require_moment();
    var crypto = require("crypto");
    var EventEmitter = require("events");
    var FileStreamRotator = {};
    module2.exports = FileStreamRotator;
    var staticFrequency = ["daily", "test", "m", "h", "custom"];
    var DATE_FORMAT = "YYYYMMDDHHmm";
    var _checkNumAndType = function(type, num) {
      if (typeof num == "number") {
        switch (type) {
          case "m":
            if (num < 0 || num > 60) {
              return false;
            }
            break;
          case "h":
            if (num < 0 || num > 24) {
              return false;
            }
            break;
        }
        return { type, digit: num };
      }
    };
    var _checkDailyAndTest = function(freqType) {
      switch (freqType) {
        case "custom":
        case "daily":
          return { type: freqType, digit: void 0 };
          break;
        case "test":
          return { type: freqType, digit: 0 };
      }
      return false;
    };
    FileStreamRotator.getFrequency = function(frequency) {
      var _f = frequency.toLowerCase().match(/^(\d+)([mh])$/);
      if (_f) {
        return _checkNumAndType(_f[2], parseInt(_f[1]));
      }
      var dailyOrTest = _checkDailyAndTest(frequency);
      if (dailyOrTest) {
        return dailyOrTest;
      }
      return false;
    };
    FileStreamRotator.parseFileSize = function(size) {
      if (size && typeof size == "string") {
        var _s = size.toLowerCase().match(/^((?:0\.)?\d+)([kmg])$/);
        if (_s) {
          switch (_s[2]) {
            case "k":
              return _s[1] * 1024;
            case "m":
              return _s[1] * 1024 * 1024;
            case "g":
              return _s[1] * 1024 * 1024 * 1024;
          }
        }
      }
      return null;
    };
    FileStreamRotator.getDate = function(format, date_format, utc) {
      date_format = date_format || DATE_FORMAT;
      let currentMoment = utc ? moment.utc() : moment().local();
      if (format && staticFrequency.indexOf(format.type) !== -1) {
        switch (format.type) {
          case "m":
            var minute = Math.floor(currentMoment.minutes() / format.digit) * format.digit;
            return currentMoment.minutes(minute).format(date_format);
            break;
          case "h":
            var hour = Math.floor(currentMoment.hour() / format.digit) * format.digit;
            return currentMoment.hour(hour).format(date_format);
            break;
          case "daily":
          case "custom":
          case "test":
            return currentMoment.format(date_format);
        }
      }
      return currentMoment.format(date_format);
    };
    FileStreamRotator.setAuditLog = function(max_logs, audit_file, log_file) {
      var _rtn = null;
      if (max_logs) {
        var use_days = max_logs.toString().substr(-1);
        var _num = max_logs.toString().match(/^(\d+)/);
        if (Number(_num[1]) > 0) {
          var baseLog = path2.dirname(log_file.replace(/%DATE%.+/, "_filename"));
          try {
            if (audit_file) {
              var full_path = path2.resolve(audit_file);
              _rtn = JSON.parse(fs2.readFileSync(full_path, { encoding: "utf-8" }));
            } else {
              var full_path = path2.resolve(baseLog + "/.audit.json");
              _rtn = JSON.parse(fs2.readFileSync(full_path, { encoding: "utf-8" }));
            }
          } catch (e) {
            if (e.code !== "ENOENT") {
              return null;
            }
            _rtn = {
              keep: {
                days: false,
                amount: Number(_num[1])
              },
              auditLog: audit_file || baseLog + "/.audit.json",
              files: []
            };
          }
          _rtn.keep = {
            days: use_days === "d",
            amount: Number(_num[1])
          };
        }
      }
      return _rtn;
    };
    FileStreamRotator.writeAuditLog = function(audit, verbose) {
      try {
        mkDirForFile(audit.auditLog);
        fs2.writeFileSync(audit.auditLog, JSON.stringify(audit, null, 4));
      } catch (e) {
        if (verbose) {
          console.error(/* @__PURE__ */ new Date(), "[FileStreamRotator] Failed to store log audit at:", audit.auditLog, "Error:", e);
        }
      }
    };
    function removeFile(file, verbose) {
      if (file.hash === crypto.createHash(file.hashType).update(file.name + "LOG_FILE" + file.date).digest("hex")) {
        try {
          if (fs2.existsSync(file.name)) {
            fs2.unlinkSync(file.name);
          }
        } catch (e) {
          if (verbose) {
            console.error(/* @__PURE__ */ new Date(), "[FileStreamRotator] Could not remove old log file: ", file.name);
          }
        }
      }
    }
    function createCurrentSymLink(logfile, name, verbose) {
      let symLinkName = name || "current.log";
      let logPath = path2.dirname(logfile);
      let logfileName = path2.basename(logfile);
      let current = logPath + "/" + symLinkName;
      try {
        let stats = fs2.lstatSync(current);
        if (stats.isSymbolicLink()) {
          fs2.unlinkSync(current);
          fs2.symlinkSync(logfileName, current);
        }
      } catch (err) {
        if (err && err.code == "ENOENT") {
          try {
            fs2.symlinkSync(logfileName, current);
          } catch (e) {
            if (verbose) {
              console.error(/* @__PURE__ */ new Date(), "[FileStreamRotator] Could not create symlink file: ", current, " -> ", logfileName);
            }
          }
        }
      }
    }
    function createLogWatcher(logfile, verbose, cb) {
      if (!logfile) return null;
      try {
        let stats = fs2.lstatSync(logfile);
        return fs2.watch(logfile, function(event, filename) {
          if (event == "rename") {
            try {
              let stats2 = fs2.lstatSync(logfile);
            } catch (err) {
              cb(err, logfile);
            }
          }
        });
      } catch (err) {
        if (verbose) {
          console.log(/* @__PURE__ */ new Date(), "[FileStreamRotator] Could not add watcher for " + logfile);
        }
      }
    }
    FileStreamRotator.addLogToAudit = function(logfile, audit, stream, verbose) {
      if (audit && audit.files) {
        var index = audit.files.findIndex(function(file) {
          return file.name === logfile;
        });
        if (index !== -1) {
          return audit;
        }
        var time = Date.now();
        audit.files.push({
          date: time,
          name: logfile,
          hash: crypto.createHash(audit.hashType).update(logfile + "LOG_FILE" + time).digest("hex")
        });
        if (audit.keep.days) {
          var oldestDate = moment().subtract(audit.keep.amount, "days").valueOf();
          var recentFiles = audit.files.filter(function(file) {
            if (file.date > oldestDate) {
              return true;
            }
            file.hashType = audit.hashType;
            removeFile(file, verbose);
            stream.emit("logRemoved", file);
            return false;
          });
          audit.files = recentFiles;
        } else {
          var filesToKeep = audit.files.splice(-audit.keep.amount);
          if (audit.files.length > 0) {
            audit.files.filter(function(file) {
              file.hashType = audit.hashType;
              removeFile(file, verbose);
              stream.emit("logRemoved", file);
              return false;
            });
          }
          audit.files = filesToKeep;
        }
        FileStreamRotator.writeAuditLog(audit, verbose);
      }
      return audit;
    };
    FileStreamRotator.getStream = function(options) {
      var frequencyMetaData = null;
      var curDate = null;
      var self2 = this;
      if (!options.filename) {
        console.error(/* @__PURE__ */ new Date(), "[FileStreamRotator] No filename supplied. Defaulting to STDOUT");
        return process.stdout;
      }
      if (options.frequency) {
        frequencyMetaData = self2.getFrequency(options.frequency);
      }
      let auditLog = self2.setAuditLog(options.max_logs, options.audit_file, options.filename);
      if (auditLog != null) {
        auditLog.hashType = options.audit_hash_type !== void 0 ? options.audit_hash_type : "md5";
      }
      self2.verbose = options.verbose !== void 0 ? options.verbose : true;
      var fileSize = null;
      var fileCount = 0;
      var curSize = 0;
      if (options.size) {
        fileSize = FileStreamRotator.parseFileSize(options.size);
      }
      var dateFormat = options.date_format || DATE_FORMAT;
      if (frequencyMetaData && frequencyMetaData.type == "daily") {
        if (!options.date_format) {
          dateFormat = "YYYY-MM-DD";
        }
        if (moment().format(dateFormat) != moment().endOf("day").format(dateFormat) || moment().format(dateFormat) == moment().add(1, "day").format(dateFormat)) {
          if (self2.verbose) {
            console.log(/* @__PURE__ */ new Date(), "[FileStreamRotator] Changing type to custom as date format changes more often than once a day or not every day");
          }
          frequencyMetaData.type = "custom";
        }
      }
      if (frequencyMetaData) {
        curDate = options.frequency ? self2.getDate(frequencyMetaData, dateFormat, options.utc) : "";
      }
      options.create_symlink = options.create_symlink || false;
      options.extension = options.extension || "";
      var filename = options.filename;
      var oldFile = null;
      var logfile = filename + (curDate ? "." + curDate : "");
      if (filename.match(/%DATE%/)) {
        logfile = filename.replace(/%DATE%/g, curDate ? curDate : self2.getDate(null, dateFormat, options.utc));
      }
      if (fileSize) {
        var lastLogFile = null;
        var t_log = logfile;
        var f = null;
        if (auditLog && auditLog.files && auditLog.files instanceof Array && auditLog.files.length > 0) {
          var lastEntry = auditLog.files[auditLog.files.length - 1].name;
          if (lastEntry.match(t_log)) {
            var lastCount = lastEntry.match(t_log + "\\.(\\d+)");
            if (lastCount) {
              t_log = lastEntry;
              fileCount = lastCount[1];
            }
          }
        }
        if (fileCount == 0 && t_log == logfile) {
          t_log += options.extension;
        }
        while (f = fs2.existsSync(t_log)) {
          lastLogFile = t_log;
          fileCount++;
          t_log = logfile + "." + fileCount + options.extension;
        }
        if (lastLogFile) {
          var lastLogFileStats = fs2.statSync(lastLogFile);
          if (lastLogFileStats.size < fileSize) {
            t_log = lastLogFile;
            fileCount--;
            curSize = lastLogFileStats.size;
          }
        }
        logfile = t_log;
      } else {
        logfile += options.extension;
      }
      if (self2.verbose) {
        console.log(/* @__PURE__ */ new Date(), "[FileStreamRotator] Logging to: ", logfile);
      }
      mkDirForFile(logfile);
      var file_options = options.file_options || { flags: "a" };
      var rotateStream = fs2.createWriteStream(logfile, file_options);
      if (curDate && frequencyMetaData && staticFrequency.indexOf(frequencyMetaData.type) > -1 || fileSize > 0) {
        if (self2.verbose) {
          console.log(/* @__PURE__ */ new Date(), "[FileStreamRotator] Rotating file: ", frequencyMetaData ? frequencyMetaData.type : "", fileSize ? "size: " + fileSize : "");
        }
        var stream = new EventEmitter();
        stream.auditLog = auditLog;
        stream.end = function() {
          rotateStream.end.apply(rotateStream, arguments);
        };
        BubbleEvents(rotateStream, stream);
        stream.on("close", function() {
          if (logWatcher) {
            logWatcher.close();
          }
        });
        stream.on("new", function(newLog) {
          stream.auditLog = self2.addLogToAudit(newLog, stream.auditLog, stream, self2.verbose);
          if (options.create_symlink) {
            createCurrentSymLink(newLog, options.symlink_name, self2.verbose);
          }
          if (options.watch_log) {
            stream.emit("addWatcher", newLog);
          }
        });
        var logWatcher;
        stream.on("addWatcher", function(newLog) {
          if (logWatcher) {
            logWatcher.close();
          }
          if (!options.watch_log) {
            return;
          }
          logWatcher = createLogWatcher(newLog, self2.verbose, function(err, newLog2) {
            stream.emit("createLog", newLog2);
          });
        });
        stream.on("createLog", function(file) {
          try {
            let stats = fs2.lstatSync(file);
          } catch (err) {
            if (rotateStream && rotateStream.end == "function") {
              rotateStream.end();
            }
            rotateStream = fs2.createWriteStream(file, file_options);
            stream.emit("new", file);
            BubbleEvents(rotateStream, stream);
          }
        });
        stream.write = (function(str, encoding) {
          var newDate = frequencyMetaData ? this.getDate(frequencyMetaData, dateFormat, options.utc) : curDate;
          if (newDate != curDate || fileSize && curSize > fileSize) {
            var newLogfile = filename + (curDate && frequencyMetaData ? "." + newDate : "");
            if (filename.match(/%DATE%/) && curDate) {
              newLogfile = filename.replace(/%DATE%/g, newDate);
            }
            if (fileSize && curSize > fileSize) {
              fileCount++;
              newLogfile += "." + fileCount + options.extension;
            } else {
              fileCount = 0;
              newLogfile += options.extension;
            }
            curSize = 0;
            if (self2.verbose) {
              console.log(/* @__PURE__ */ new Date(), require("util").format("[FileStreamRotator] Changing logs from %s to %s", logfile, newLogfile));
            }
            curDate = newDate;
            oldFile = logfile;
            logfile = newLogfile;
            if (options.end_stream === true) {
              rotateStream.end();
            } else {
              rotateStream.destroy();
            }
            mkDirForFile(logfile);
            rotateStream = fs2.createWriteStream(newLogfile, file_options);
            stream.emit("new", newLogfile);
            stream.emit("rotate", oldFile, newLogfile);
            BubbleEvents(rotateStream, stream);
          }
          rotateStream.write(str, encoding);
          curSize += Buffer.byteLength(str, encoding);
        }).bind(this);
        process.nextTick(function() {
          stream.emit("new", logfile);
        });
        stream.emit("new", logfile);
        return stream;
      } else {
        if (self2.verbose) {
          console.log(/* @__PURE__ */ new Date(), "[FileStreamRotator] File won't be rotated: ", options.frequency, options.size);
        }
        process.nextTick(function() {
          rotateStream.emit("new", logfile);
        });
        return rotateStream;
      }
    };
    var mkDirForFile = function(pathWithFile) {
      var _path = path2.dirname(pathWithFile);
      _path.split(path2.sep).reduce(
        function(fullPath, folder) {
          fullPath += folder + path2.sep;
          if (!fs2.existsSync(fullPath)) {
            try {
              fs2.mkdirSync(fullPath);
            } catch (e) {
              if (e.code !== "EEXIST") {
                throw e;
              }
            }
          }
          return fullPath;
        },
        ""
      );
    };
    var BubbleEvents = function BubbleEvents2(emitter, proxy) {
      emitter.on("close", function() {
        proxy.emit("close");
      });
      emitter.on("finish", function() {
        proxy.emit("finish");
      });
      emitter.on("error", function(err) {
        proxy.emit("error", err);
      });
      emitter.on("open", function(fd) {
        proxy.emit("open", fd);
      });
    };
  }
});

// node_modules/winston-daily-rotate-file/daily-rotate-file.js
var require_daily_rotate_file = __commonJS({
  "node_modules/winston-daily-rotate-file/daily-rotate-file.js"(exports2, module2) {
    var fs2 = require("fs");
    var os2 = require("os");
    var path2 = require("path");
    var util = require("util");
    var zlib = require("zlib");
    var hash = require_object_hash();
    var MESSAGE = require_triple_beam().MESSAGE;
    var PassThrough = require("stream").PassThrough;
    var Transport = require_winston_transport();
    var loggerDefaults = {
      json: false,
      colorize: false,
      eol: os2.EOL,
      logstash: null,
      prettyPrint: false,
      label: null,
      stringify: false,
      depth: null,
      showLevel: true,
      timestamp: () => {
        return (/* @__PURE__ */ new Date()).toISOString();
      }
    };
    var DailyRotateFile2 = function(options) {
      options = options || {};
      Transport.call(this, options);
      function throwIf(target) {
        Array.prototype.slice.call(arguments, 1).forEach((name) => {
          if (options[name]) {
            throw new Error("Cannot set " + name + " and " + target + " together");
          }
        });
      }
      function getMaxSize(size) {
        if (size && typeof size === "string") {
          if (size.toLowerCase().match(/^((?:0\.)?\d+)([kmg])$/)) {
            return size;
          }
        } else if (size && Number.isInteger(size)) {
          const sizeK = Math.round(size / 1024);
          return sizeK === 0 ? "1k" : sizeK + "k";
        }
        return null;
      }
      function isValidFileName(filename) {
        return !/["<>|:*?\\/\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f]/g.test(
          filename
        );
      }
      function isValidDirName(dirname) {
        return !/["<>|\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f]/g.test(
          dirname
        );
      }
      this.options = Object.assign({}, loggerDefaults, options);
      if (options.stream) {
        throwIf("stream", "filename", "maxsize");
        this.logStream = new PassThrough();
        this.logStream.pipe(options.stream);
      } else {
        this.filename = options.filename ? path2.basename(options.filename) : "winston.log";
        this.dirname = options.dirname || path2.dirname(options.filename);
        if (!isValidFileName(this.filename) || !isValidDirName(this.dirname)) {
          throw new Error("Your path or filename contain an invalid character.");
        }
        this.logStream = require_FileStreamRotator().getStream({
          filename: path2.join(this.dirname, this.filename),
          frequency: options.frequency ? options.frequency : "custom",
          date_format: options.datePattern ? options.datePattern : "YYYY-MM-DD",
          verbose: false,
          size: getMaxSize(options.maxSize),
          max_logs: options.maxFiles,
          end_stream: true,
          audit_file: options.auditFile ? options.auditFile : path2.join(this.dirname, "." + hash(options) + "-audit.json"),
          file_options: options.options ? options.options : { flags: "a" },
          utc: options.utc ? options.utc : false,
          extension: options.extension ? options.extension : "",
          create_symlink: options.createSymlink ? options.createSymlink : false,
          symlink_name: options.symlinkName ? options.symlinkName : "current.log",
          watch_log: options.watchLog ? options.watchLog : false,
          audit_hash_type: options.auditHashType ? options.auditHashType : "sha256"
        });
        this.logStream.on("new", (newFile) => {
          this.emit("new", newFile);
        });
        this.logStream.on("rotate", (oldFile, newFile) => {
          this.emit("rotate", oldFile, newFile);
        });
        this.logStream.on("logRemoved", (params) => {
          if (options.zippedArchive) {
            const gzName = params.name + ".gz";
            try {
              fs2.unlinkSync(gzName);
            } catch (err) {
              if (err.code !== "ENOENT") {
                err.message = `Error occurred while removing ${gzName}: ${err.message}`;
                this.emit("error", err);
                return;
              }
            }
            this.emit("logRemoved", gzName);
            return;
          }
          this.emit("logRemoved", params.name);
        });
        if (options.zippedArchive) {
          this.logStream.on("rotate", (oldFile) => {
            try {
              if (!fs2.existsSync(oldFile)) {
                return;
              }
            } catch (err) {
              err.message = `Error occurred while checking existence of ${oldFile}: ${err.message}`;
              this.emit("error", err);
              return;
            }
            try {
              if (fs2.existsSync(`${oldFile}.gz`)) {
                return;
              }
            } catch (err) {
              err.message = `Error occurred while checking existence of ${oldFile}.gz: ${err.message}`;
              this.emit("error", err);
              return;
            }
            const gzip = zlib.createGzip();
            const inp = fs2.createReadStream(oldFile);
            inp.on("error", (err) => {
              err.message = `Error occurred while reading ${oldFile}: ${err.message}`;
              this.emit("error", err);
            });
            const out = fs2.createWriteStream(oldFile + ".gz");
            out.on("error", (err) => {
              err.message = `Error occurred while writing ${oldFile}.gz: ${err.message}`;
              this.emit("error", err);
            });
            inp.pipe(gzip).pipe(out).on("finish", () => {
              try {
                fs2.unlinkSync(oldFile);
              } catch (err) {
                if (err.code !== "ENOENT") {
                  err.message = `Error occurred while removing ${oldFile}: ${err.message}`;
                  this.emit("error", err);
                  return;
                }
              }
              this.emit("archive", oldFile + ".gz");
            });
          });
        }
        if (options.watchLog) {
          this.logStream.on("addWatcher", (newFile) => {
            this.emit("addWatcher", newFile);
          });
        }
      }
    };
    module2.exports = DailyRotateFile2;
    util.inherits(DailyRotateFile2, Transport);
    DailyRotateFile2.prototype.name = "dailyRotateFile";
    var noop = function() {
    };
    DailyRotateFile2.prototype.log = function(info, callback) {
      callback = callback || noop;
      this.logStream.write(info[MESSAGE] + this.options.eol);
      this.emit("logged", info);
      callback(null, true);
    };
    DailyRotateFile2.prototype.close = function() {
      if (this.logStream) {
        this.logStream.end(() => {
          this.emit("finish");
        });
      }
    };
    DailyRotateFile2.prototype.query = function(options, callback) {
      if (typeof options === "function") {
        callback = options;
        options = {};
      }
      if (!this.options.json) {
        throw new Error(
          "query() may not be used without the json option being set to true"
        );
      }
      if (!this.filename) {
        throw new Error("query() may not be used when initializing with a stream");
      }
      let results = [];
      options = options || {};
      options.rows = options.rows || options.limit || 10;
      options.start = options.start || 0;
      options.until = options.until || /* @__PURE__ */ new Date();
      if (typeof options.until !== "object") {
        options.until = new Date(options.until);
      }
      options.from = options.from || options.until - 24 * 60 * 60 * 1e3;
      if (typeof options.from !== "object") {
        options.from = new Date(options.from);
      }
      options.order = options.order || "desc";
      const logFiles = (() => {
        const fileRegex = new RegExp(this.filename.replace("%DATE%", ".*"), "i");
        return fs2.readdirSync(this.dirname).filter((file) => path2.basename(file).match(fileRegex));
      })();
      if (logFiles.length === 0 && callback) {
        callback(null, results);
      }
      const processLogFile = (file) => {
        if (!file) {
          return;
        }
        const logFile = path2.join(this.dirname, file);
        let buff = "";
        let stream;
        if (file.endsWith(".gz")) {
          stream = new PassThrough();
          const inp = fs2.createReadStream(logFile);
          inp.on("error", (err) => {
            err.message = `Error occurred while reading ${logFile}: ${err.message}`;
            stream.emit("error", err);
          });
          inp.pipe(zlib.createGunzip()).pipe(stream);
        } else {
          stream = fs2.createReadStream(logFile, {
            encoding: "utf8"
          });
        }
        stream.on("error", (err) => {
          if (stream.readable) {
            stream.destroy();
          }
          if (!callback) {
            return;
          }
          return err.code === "ENOENT" ? callback(null, results) : callback(err);
        });
        stream.on("data", (data) => {
          data = (buff + data).split(/\n+/);
          const l = data.length - 1;
          for (let i = 0; i < l; i++) {
            add(data[i]);
          }
          buff = data[l];
        });
        stream.on("end", () => {
          if (buff) {
            add(buff, true);
          }
          if (logFiles.length) {
            processLogFile(logFiles.shift());
          } else if (callback) {
            results.sort((a, b) => {
              const d1 = new Date(a.timestamp).getTime();
              const d2 = new Date(b.timestamp).getTime();
              return d1 > d2 ? 1 : d1 < d2 ? -1 : 0;
            });
            if (options.order === "desc") {
              results = results.reverse();
            }
            const start = options.start || 0;
            const limit = options.limit || results.length;
            results = results.slice(start, start + limit);
            if (options.fields) {
              results = results.map((log) => {
                const obj = {};
                options.fields.forEach((key) => {
                  obj[key] = log[key];
                });
                return obj;
              });
            }
            callback(null, results);
          }
        });
        function add(buff2, attempt) {
          try {
            const log = JSON.parse(buff2);
            if (!log || typeof log !== "object") {
              return;
            }
            const time = new Date(log.timestamp);
            if (options.from && time < options.from || options.until && time > options.until || options.level && options.level !== log.level) {
              return;
            }
            results.push(log);
          } catch (e) {
            if (!attempt) {
              stream.emit("error", e);
            }
          }
        }
      };
      processLogFile(logFiles.shift());
    };
  }
});

// node_modules/winston-daily-rotate-file/index.js
var require_winston_daily_rotate_file = __commonJS({
  "node_modules/winston-daily-rotate-file/index.js"(exports2, module2) {
    var winston2 = require_winston();
    var DailyRotateFile2 = require_daily_rotate_file();
    winston2.transports.DailyRotateFile = DailyRotateFile2;
    module2.exports = DailyRotateFile2;
  }
});

// node_modules/ws/lib/constants.js
var require_constants = __commonJS({
  "node_modules/ws/lib/constants.js"(exports2, module2) {
    "use strict";
    var BINARY_TYPES = ["nodebuffer", "arraybuffer", "fragments"];
    var hasBlob = typeof Blob !== "undefined";
    if (hasBlob) BINARY_TYPES.push("blob");
    module2.exports = {
      BINARY_TYPES,
      CLOSE_TIMEOUT: 3e4,
      EMPTY_BUFFER: Buffer.alloc(0),
      GUID: "258EAFA5-E914-47DA-95CA-C5AB0DC85B11",
      hasBlob,
      kForOnEventAttribute: /* @__PURE__ */ Symbol("kIsForOnEventAttribute"),
      kListener: /* @__PURE__ */ Symbol("kListener"),
      kStatusCode: /* @__PURE__ */ Symbol("status-code"),
      kWebSocket: /* @__PURE__ */ Symbol("websocket"),
      NOOP: () => {
      }
    };
  }
});

// node_modules/ws/lib/buffer-util.js
var require_buffer_util = __commonJS({
  "node_modules/ws/lib/buffer-util.js"(exports2, module2) {
    "use strict";
    var { EMPTY_BUFFER } = require_constants();
    var FastBuffer = Buffer[Symbol.species];
    function concat(list, totalLength) {
      if (list.length === 0) return EMPTY_BUFFER;
      if (list.length === 1) return list[0];
      const target = Buffer.allocUnsafe(totalLength);
      let offset = 0;
      for (let i = 0; i < list.length; i++) {
        const buf = list[i];
        target.set(buf, offset);
        offset += buf.length;
      }
      if (offset < totalLength) {
        return new FastBuffer(target.buffer, target.byteOffset, offset);
      }
      return target;
    }
    function _mask(source, mask, output, offset, length) {
      for (let i = 0; i < length; i++) {
        output[offset + i] = source[i] ^ mask[i & 3];
      }
    }
    function _unmask(buffer, mask) {
      for (let i = 0; i < buffer.length; i++) {
        buffer[i] ^= mask[i & 3];
      }
    }
    function toArrayBuffer(buf) {
      if (buf.length === buf.buffer.byteLength) {
        return buf.buffer;
      }
      return buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.length);
    }
    function toBuffer(data) {
      toBuffer.readOnly = true;
      if (Buffer.isBuffer(data)) return data;
      let buf;
      if (data instanceof ArrayBuffer) {
        buf = new FastBuffer(data);
      } else if (ArrayBuffer.isView(data)) {
        buf = new FastBuffer(data.buffer, data.byteOffset, data.byteLength);
      } else {
        buf = Buffer.from(data);
        toBuffer.readOnly = false;
      }
      return buf;
    }
    module2.exports = {
      concat,
      mask: _mask,
      toArrayBuffer,
      toBuffer,
      unmask: _unmask
    };
    if (!process.env.WS_NO_BUFFER_UTIL) {
      try {
        const bufferUtil = require("bufferutil");
        module2.exports.mask = function(source, mask, output, offset, length) {
          if (length < 48) _mask(source, mask, output, offset, length);
          else bufferUtil.mask(source, mask, output, offset, length);
        };
        module2.exports.unmask = function(buffer, mask) {
          if (buffer.length < 32) _unmask(buffer, mask);
          else bufferUtil.unmask(buffer, mask);
        };
      } catch (e) {
      }
    }
  }
});

// node_modules/ws/lib/limiter.js
var require_limiter = __commonJS({
  "node_modules/ws/lib/limiter.js"(exports2, module2) {
    "use strict";
    var kDone = /* @__PURE__ */ Symbol("kDone");
    var kRun = /* @__PURE__ */ Symbol("kRun");
    var Limiter = class {
      /**
       * Creates a new `Limiter`.
       *
       * @param {Number} [concurrency=Infinity] The maximum number of jobs allowed
       *     to run concurrently
       */
      constructor(concurrency) {
        this[kDone] = () => {
          this.pending--;
          this[kRun]();
        };
        this.concurrency = concurrency || Infinity;
        this.jobs = [];
        this.pending = 0;
      }
      /**
       * Adds a job to the queue.
       *
       * @param {Function} job The job to run
       * @public
       */
      add(job) {
        this.jobs.push(job);
        this[kRun]();
      }
      /**
       * Removes a job from the queue and runs it if possible.
       *
       * @private
       */
      [kRun]() {
        if (this.pending === this.concurrency) return;
        if (this.jobs.length) {
          const job = this.jobs.shift();
          this.pending++;
          job(this[kDone]);
        }
      }
    };
    module2.exports = Limiter;
  }
});

// node_modules/ws/lib/permessage-deflate.js
var require_permessage_deflate = __commonJS({
  "node_modules/ws/lib/permessage-deflate.js"(exports2, module2) {
    "use strict";
    var zlib = require("zlib");
    var bufferUtil = require_buffer_util();
    var Limiter = require_limiter();
    var { kStatusCode } = require_constants();
    var FastBuffer = Buffer[Symbol.species];
    var TRAILER = Buffer.from([0, 0, 255, 255]);
    var kPerMessageDeflate = /* @__PURE__ */ Symbol("permessage-deflate");
    var kTotalLength = /* @__PURE__ */ Symbol("total-length");
    var kCallback = /* @__PURE__ */ Symbol("callback");
    var kBuffers = /* @__PURE__ */ Symbol("buffers");
    var kError = /* @__PURE__ */ Symbol("error");
    var zlibLimiter;
    var PerMessageDeflate2 = class {
      /**
       * Creates a PerMessageDeflate instance.
       *
       * @param {Object} [options] Configuration options
       * @param {(Boolean|Number)} [options.clientMaxWindowBits] Advertise support
       *     for, or request, a custom client window size
       * @param {Boolean} [options.clientNoContextTakeover=false] Advertise/
       *     acknowledge disabling of client context takeover
       * @param {Number} [options.concurrencyLimit=10] The number of concurrent
       *     calls to zlib
       * @param {Boolean} [options.isServer=false] Create the instance in either
       *     server or client mode
       * @param {Number} [options.maxPayload=0] The maximum allowed message length
       * @param {(Boolean|Number)} [options.serverMaxWindowBits] Request/confirm the
       *     use of a custom server window size
       * @param {Boolean} [options.serverNoContextTakeover=false] Request/accept
       *     disabling of server context takeover
       * @param {Number} [options.threshold=1024] Size (in bytes) below which
       *     messages should not be compressed if context takeover is disabled
       * @param {Object} [options.zlibDeflateOptions] Options to pass to zlib on
       *     deflate
       * @param {Object} [options.zlibInflateOptions] Options to pass to zlib on
       *     inflate
       */
      constructor(options) {
        this._options = options || {};
        this._threshold = this._options.threshold !== void 0 ? this._options.threshold : 1024;
        this._maxPayload = this._options.maxPayload | 0;
        this._isServer = !!this._options.isServer;
        this._deflate = null;
        this._inflate = null;
        this.params = null;
        if (!zlibLimiter) {
          const concurrency = this._options.concurrencyLimit !== void 0 ? this._options.concurrencyLimit : 10;
          zlibLimiter = new Limiter(concurrency);
        }
      }
      /**
       * @type {String}
       */
      static get extensionName() {
        return "permessage-deflate";
      }
      /**
       * Create an extension negotiation offer.
       *
       * @return {Object} Extension parameters
       * @public
       */
      offer() {
        const params = {};
        if (this._options.serverNoContextTakeover) {
          params.server_no_context_takeover = true;
        }
        if (this._options.clientNoContextTakeover) {
          params.client_no_context_takeover = true;
        }
        if (this._options.serverMaxWindowBits) {
          params.server_max_window_bits = this._options.serverMaxWindowBits;
        }
        if (this._options.clientMaxWindowBits) {
          params.client_max_window_bits = this._options.clientMaxWindowBits;
        } else if (this._options.clientMaxWindowBits == null) {
          params.client_max_window_bits = true;
        }
        return params;
      }
      /**
       * Accept an extension negotiation offer/response.
       *
       * @param {Array} configurations The extension negotiation offers/reponse
       * @return {Object} Accepted configuration
       * @public
       */
      accept(configurations) {
        configurations = this.normalizeParams(configurations);
        this.params = this._isServer ? this.acceptAsServer(configurations) : this.acceptAsClient(configurations);
        return this.params;
      }
      /**
       * Releases all resources used by the extension.
       *
       * @public
       */
      cleanup() {
        if (this._inflate) {
          this._inflate.close();
          this._inflate = null;
        }
        if (this._deflate) {
          const callback = this._deflate[kCallback];
          this._deflate.close();
          this._deflate = null;
          if (callback) {
            callback(
              new Error(
                "The deflate stream was closed while data was being processed"
              )
            );
          }
        }
      }
      /**
       *  Accept an extension negotiation offer.
       *
       * @param {Array} offers The extension negotiation offers
       * @return {Object} Accepted configuration
       * @private
       */
      acceptAsServer(offers) {
        const opts = this._options;
        const accepted = offers.find((params) => {
          if (opts.serverNoContextTakeover === false && params.server_no_context_takeover || params.server_max_window_bits && (opts.serverMaxWindowBits === false || typeof opts.serverMaxWindowBits === "number" && opts.serverMaxWindowBits > params.server_max_window_bits) || typeof opts.clientMaxWindowBits === "number" && (typeof params.client_max_window_bits === "number" ? opts.clientMaxWindowBits > params.client_max_window_bits : !params.client_max_window_bits)) {
            return false;
          }
          return true;
        });
        if (!accepted) {
          throw new Error("None of the extension offers can be accepted");
        }
        if (opts.serverNoContextTakeover) {
          accepted.server_no_context_takeover = true;
        }
        if (opts.clientNoContextTakeover) {
          accepted.client_no_context_takeover = true;
        }
        if (typeof opts.serverMaxWindowBits === "number") {
          accepted.server_max_window_bits = opts.serverMaxWindowBits;
        }
        if (typeof opts.clientMaxWindowBits === "number") {
          accepted.client_max_window_bits = opts.clientMaxWindowBits;
        } else if (accepted.client_max_window_bits === true || opts.clientMaxWindowBits === false) {
          delete accepted.client_max_window_bits;
        }
        return accepted;
      }
      /**
       * Accept the extension negotiation response.
       *
       * @param {Array} response The extension negotiation response
       * @return {Object} Accepted configuration
       * @private
       */
      acceptAsClient(response) {
        const params = response[0];
        if (this._options.clientNoContextTakeover === false && params.client_no_context_takeover) {
          throw new Error('Unexpected parameter "client_no_context_takeover"');
        }
        if (!params.client_max_window_bits) {
          if (typeof this._options.clientMaxWindowBits === "number") {
            params.client_max_window_bits = this._options.clientMaxWindowBits;
          }
        } else if (this._options.clientMaxWindowBits === false || typeof this._options.clientMaxWindowBits === "number" && params.client_max_window_bits > this._options.clientMaxWindowBits) {
          throw new Error(
            'Unexpected or invalid parameter "client_max_window_bits"'
          );
        }
        return params;
      }
      /**
       * Normalize parameters.
       *
       * @param {Array} configurations The extension negotiation offers/reponse
       * @return {Array} The offers/response with normalized parameters
       * @private
       */
      normalizeParams(configurations) {
        configurations.forEach((params) => {
          Object.keys(params).forEach((key) => {
            let value = params[key];
            if (value.length > 1) {
              throw new Error(`Parameter "${key}" must have only a single value`);
            }
            value = value[0];
            if (key === "client_max_window_bits") {
              if (value !== true) {
                const num = +value;
                if (!Number.isInteger(num) || num < 8 || num > 15) {
                  throw new TypeError(
                    `Invalid value for parameter "${key}": ${value}`
                  );
                }
                value = num;
              } else if (!this._isServer) {
                throw new TypeError(
                  `Invalid value for parameter "${key}": ${value}`
                );
              }
            } else if (key === "server_max_window_bits") {
              const num = +value;
              if (!Number.isInteger(num) || num < 8 || num > 15) {
                throw new TypeError(
                  `Invalid value for parameter "${key}": ${value}`
                );
              }
              value = num;
            } else if (key === "client_no_context_takeover" || key === "server_no_context_takeover") {
              if (value !== true) {
                throw new TypeError(
                  `Invalid value for parameter "${key}": ${value}`
                );
              }
            } else {
              throw new Error(`Unknown parameter "${key}"`);
            }
            params[key] = value;
          });
        });
        return configurations;
      }
      /**
       * Decompress data. Concurrency limited.
       *
       * @param {Buffer} data Compressed data
       * @param {Boolean} fin Specifies whether or not this is the last fragment
       * @param {Function} callback Callback
       * @public
       */
      decompress(data, fin, callback) {
        zlibLimiter.add((done) => {
          this._decompress(data, fin, (err, result) => {
            done();
            callback(err, result);
          });
        });
      }
      /**
       * Compress data. Concurrency limited.
       *
       * @param {(Buffer|String)} data Data to compress
       * @param {Boolean} fin Specifies whether or not this is the last fragment
       * @param {Function} callback Callback
       * @public
       */
      compress(data, fin, callback) {
        zlibLimiter.add((done) => {
          this._compress(data, fin, (err, result) => {
            done();
            callback(err, result);
          });
        });
      }
      /**
       * Decompress data.
       *
       * @param {Buffer} data Compressed data
       * @param {Boolean} fin Specifies whether or not this is the last fragment
       * @param {Function} callback Callback
       * @private
       */
      _decompress(data, fin, callback) {
        const endpoint = this._isServer ? "client" : "server";
        if (!this._inflate) {
          const key = `${endpoint}_max_window_bits`;
          const windowBits = typeof this.params[key] !== "number" ? zlib.Z_DEFAULT_WINDOWBITS : this.params[key];
          this._inflate = zlib.createInflateRaw({
            ...this._options.zlibInflateOptions,
            windowBits
          });
          this._inflate[kPerMessageDeflate] = this;
          this._inflate[kTotalLength] = 0;
          this._inflate[kBuffers] = [];
          this._inflate.on("error", inflateOnError);
          this._inflate.on("data", inflateOnData);
        }
        this._inflate[kCallback] = callback;
        this._inflate.write(data);
        if (fin) this._inflate.write(TRAILER);
        this._inflate.flush(() => {
          const err = this._inflate[kError];
          if (err) {
            this._inflate.close();
            this._inflate = null;
            callback(err);
            return;
          }
          const data2 = bufferUtil.concat(
            this._inflate[kBuffers],
            this._inflate[kTotalLength]
          );
          if (this._inflate._readableState.endEmitted) {
            this._inflate.close();
            this._inflate = null;
          } else {
            this._inflate[kTotalLength] = 0;
            this._inflate[kBuffers] = [];
            if (fin && this.params[`${endpoint}_no_context_takeover`]) {
              this._inflate.reset();
            }
          }
          callback(null, data2);
        });
      }
      /**
       * Compress data.
       *
       * @param {(Buffer|String)} data Data to compress
       * @param {Boolean} fin Specifies whether or not this is the last fragment
       * @param {Function} callback Callback
       * @private
       */
      _compress(data, fin, callback) {
        const endpoint = this._isServer ? "server" : "client";
        if (!this._deflate) {
          const key = `${endpoint}_max_window_bits`;
          const windowBits = typeof this.params[key] !== "number" ? zlib.Z_DEFAULT_WINDOWBITS : this.params[key];
          this._deflate = zlib.createDeflateRaw({
            ...this._options.zlibDeflateOptions,
            windowBits
          });
          this._deflate[kTotalLength] = 0;
          this._deflate[kBuffers] = [];
          this._deflate.on("data", deflateOnData);
        }
        this._deflate[kCallback] = callback;
        this._deflate.write(data);
        this._deflate.flush(zlib.Z_SYNC_FLUSH, () => {
          if (!this._deflate) {
            return;
          }
          let data2 = bufferUtil.concat(
            this._deflate[kBuffers],
            this._deflate[kTotalLength]
          );
          if (fin) {
            data2 = new FastBuffer(data2.buffer, data2.byteOffset, data2.length - 4);
          }
          this._deflate[kCallback] = null;
          this._deflate[kTotalLength] = 0;
          this._deflate[kBuffers] = [];
          if (fin && this.params[`${endpoint}_no_context_takeover`]) {
            this._deflate.reset();
          }
          callback(null, data2);
        });
      }
    };
    module2.exports = PerMessageDeflate2;
    function deflateOnData(chunk) {
      this[kBuffers].push(chunk);
      this[kTotalLength] += chunk.length;
    }
    function inflateOnData(chunk) {
      this[kTotalLength] += chunk.length;
      if (this[kPerMessageDeflate]._maxPayload < 1 || this[kTotalLength] <= this[kPerMessageDeflate]._maxPayload) {
        this[kBuffers].push(chunk);
        return;
      }
      this[kError] = new RangeError("Max payload size exceeded");
      this[kError].code = "WS_ERR_UNSUPPORTED_MESSAGE_LENGTH";
      this[kError][kStatusCode] = 1009;
      this.removeListener("data", inflateOnData);
      this.reset();
    }
    function inflateOnError(err) {
      this[kPerMessageDeflate]._inflate = null;
      if (this[kError]) {
        this[kCallback](this[kError]);
        return;
      }
      err[kStatusCode] = 1007;
      this[kCallback](err);
    }
  }
});

// node_modules/ws/lib/validation.js
var require_validation = __commonJS({
  "node_modules/ws/lib/validation.js"(exports2, module2) {
    "use strict";
    var { isUtf8 } = require("buffer");
    var { hasBlob } = require_constants();
    var tokenChars = [
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      // 0 - 15
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      // 16 - 31
      0,
      1,
      0,
      1,
      1,
      1,
      1,
      1,
      0,
      0,
      1,
      1,
      0,
      1,
      1,
      0,
      // 32 - 47
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      0,
      0,
      0,
      0,
      0,
      0,
      // 48 - 63
      0,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      // 64 - 79
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      0,
      0,
      0,
      1,
      1,
      // 80 - 95
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      // 96 - 111
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      0,
      1,
      0,
      1,
      0
      // 112 - 127
    ];
    function isValidStatusCode(code) {
      return code >= 1e3 && code <= 1014 && code !== 1004 && code !== 1005 && code !== 1006 || code >= 3e3 && code <= 4999;
    }
    function _isValidUTF8(buf) {
      const len = buf.length;
      let i = 0;
      while (i < len) {
        if ((buf[i] & 128) === 0) {
          i++;
        } else if ((buf[i] & 224) === 192) {
          if (i + 1 === len || (buf[i + 1] & 192) !== 128 || (buf[i] & 254) === 192) {
            return false;
          }
          i += 2;
        } else if ((buf[i] & 240) === 224) {
          if (i + 2 >= len || (buf[i + 1] & 192) !== 128 || (buf[i + 2] & 192) !== 128 || buf[i] === 224 && (buf[i + 1] & 224) === 128 || // Overlong
          buf[i] === 237 && (buf[i + 1] & 224) === 160) {
            return false;
          }
          i += 3;
        } else if ((buf[i] & 248) === 240) {
          if (i + 3 >= len || (buf[i + 1] & 192) !== 128 || (buf[i + 2] & 192) !== 128 || (buf[i + 3] & 192) !== 128 || buf[i] === 240 && (buf[i + 1] & 240) === 128 || // Overlong
          buf[i] === 244 && buf[i + 1] > 143 || buf[i] > 244) {
            return false;
          }
          i += 4;
        } else {
          return false;
        }
      }
      return true;
    }
    function isBlob(value) {
      return hasBlob && typeof value === "object" && typeof value.arrayBuffer === "function" && typeof value.type === "string" && typeof value.stream === "function" && (value[Symbol.toStringTag] === "Blob" || value[Symbol.toStringTag] === "File");
    }
    module2.exports = {
      isBlob,
      isValidStatusCode,
      isValidUTF8: _isValidUTF8,
      tokenChars
    };
    if (isUtf8) {
      module2.exports.isValidUTF8 = function(buf) {
        return buf.length < 24 ? _isValidUTF8(buf) : isUtf8(buf);
      };
    } else if (!process.env.WS_NO_UTF_8_VALIDATE) {
      try {
        const isValidUTF8 = require("utf-8-validate");
        module2.exports.isValidUTF8 = function(buf) {
          return buf.length < 32 ? _isValidUTF8(buf) : isValidUTF8(buf);
        };
      } catch (e) {
      }
    }
  }
});

// node_modules/ws/lib/receiver.js
var require_receiver = __commonJS({
  "node_modules/ws/lib/receiver.js"(exports2, module2) {
    "use strict";
    var { Writable } = require("stream");
    var PerMessageDeflate2 = require_permessage_deflate();
    var {
      BINARY_TYPES,
      EMPTY_BUFFER,
      kStatusCode,
      kWebSocket
    } = require_constants();
    var { concat, toArrayBuffer, unmask } = require_buffer_util();
    var { isValidStatusCode, isValidUTF8 } = require_validation();
    var FastBuffer = Buffer[Symbol.species];
    var GET_INFO = 0;
    var GET_PAYLOAD_LENGTH_16 = 1;
    var GET_PAYLOAD_LENGTH_64 = 2;
    var GET_MASK = 3;
    var GET_DATA = 4;
    var INFLATING = 5;
    var DEFER_EVENT = 6;
    var Receiver2 = class extends Writable {
      /**
       * Creates a Receiver instance.
       *
       * @param {Object} [options] Options object
       * @param {Boolean} [options.allowSynchronousEvents=true] Specifies whether
       *     any of the `'message'`, `'ping'`, and `'pong'` events can be emitted
       *     multiple times in the same tick
       * @param {String} [options.binaryType=nodebuffer] The type for binary data
       * @param {Object} [options.extensions] An object containing the negotiated
       *     extensions
       * @param {Boolean} [options.isServer=false] Specifies whether to operate in
       *     client or server mode
       * @param {Number} [options.maxBufferedChunks=0] The maximum number of
       *     buffered data chunks
       * @param {Number} [options.maxFragments=0] The maximum number of message
       *     fragments
       * @param {Number} [options.maxPayload=0] The maximum allowed message length
       * @param {Boolean} [options.skipUTF8Validation=false] Specifies whether or
       *     not to skip UTF-8 validation for text and close messages
       */
      constructor(options = {}) {
        super();
        this._allowSynchronousEvents = options.allowSynchronousEvents !== void 0 ? options.allowSynchronousEvents : true;
        this._binaryType = options.binaryType || BINARY_TYPES[0];
        this._extensions = options.extensions || {};
        this._isServer = !!options.isServer;
        this._maxBufferedChunks = options.maxBufferedChunks | 0;
        this._maxFragments = options.maxFragments | 0;
        this._maxPayload = options.maxPayload | 0;
        this._skipUTF8Validation = !!options.skipUTF8Validation;
        this[kWebSocket] = void 0;
        this._bufferedBytes = 0;
        this._buffers = [];
        this._compressed = false;
        this._payloadLength = 0;
        this._mask = void 0;
        this._fragmented = 0;
        this._masked = false;
        this._fin = false;
        this._opcode = 0;
        this._totalPayloadLength = 0;
        this._messageLength = 0;
        this._numFragments = 0;
        this._fragments = [];
        this._errored = false;
        this._loop = false;
        this._state = GET_INFO;
      }
      /**
       * Implements `Writable.prototype._write()`.
       *
       * @param {Buffer} chunk The chunk of data to write
       * @param {String} encoding The character encoding of `chunk`
       * @param {Function} cb Callback
       * @private
       */
      _write(chunk, encoding, cb) {
        if (this._opcode === 8 && this._state == GET_INFO) return cb();
        if (this._maxBufferedChunks > 0 && this._buffers.length >= this._maxBufferedChunks) {
          cb(
            this.createError(
              RangeError,
              "Too many buffered chunks",
              false,
              1008,
              "WS_ERR_TOO_MANY_BUFFERED_PARTS"
            )
          );
          return;
        }
        this._bufferedBytes += chunk.length;
        this._buffers.push(chunk);
        this.startLoop(cb);
      }
      /**
       * Consumes `n` bytes from the buffered data.
       *
       * @param {Number} n The number of bytes to consume
       * @return {Buffer} The consumed bytes
       * @private
       */
      consume(n) {
        this._bufferedBytes -= n;
        if (n === this._buffers[0].length) return this._buffers.shift();
        if (n < this._buffers[0].length) {
          const buf = this._buffers[0];
          this._buffers[0] = new FastBuffer(
            buf.buffer,
            buf.byteOffset + n,
            buf.length - n
          );
          return new FastBuffer(buf.buffer, buf.byteOffset, n);
        }
        const dst = Buffer.allocUnsafe(n);
        do {
          const buf = this._buffers[0];
          const offset = dst.length - n;
          if (n >= buf.length) {
            dst.set(this._buffers.shift(), offset);
          } else {
            dst.set(new Uint8Array(buf.buffer, buf.byteOffset, n), offset);
            this._buffers[0] = new FastBuffer(
              buf.buffer,
              buf.byteOffset + n,
              buf.length - n
            );
          }
          n -= buf.length;
        } while (n > 0);
        return dst;
      }
      /**
       * Starts the parsing loop.
       *
       * @param {Function} cb Callback
       * @private
       */
      startLoop(cb) {
        this._loop = true;
        do {
          switch (this._state) {
            case GET_INFO:
              this.getInfo(cb);
              break;
            case GET_PAYLOAD_LENGTH_16:
              this.getPayloadLength16(cb);
              break;
            case GET_PAYLOAD_LENGTH_64:
              this.getPayloadLength64(cb);
              break;
            case GET_MASK:
              this.getMask();
              break;
            case GET_DATA:
              this.getData(cb);
              break;
            case INFLATING:
            case DEFER_EVENT:
              this._loop = false;
              return;
          }
        } while (this._loop);
        if (!this._errored) cb();
      }
      /**
       * Reads the first two bytes of a frame.
       *
       * @param {Function} cb Callback
       * @private
       */
      getInfo(cb) {
        if (this._bufferedBytes < 2) {
          this._loop = false;
          return;
        }
        const buf = this.consume(2);
        if ((buf[0] & 48) !== 0) {
          const error = this.createError(
            RangeError,
            "RSV2 and RSV3 must be clear",
            true,
            1002,
            "WS_ERR_UNEXPECTED_RSV_2_3"
          );
          cb(error);
          return;
        }
        const compressed = (buf[0] & 64) === 64;
        if (compressed && !this._extensions[PerMessageDeflate2.extensionName]) {
          const error = this.createError(
            RangeError,
            "RSV1 must be clear",
            true,
            1002,
            "WS_ERR_UNEXPECTED_RSV_1"
          );
          cb(error);
          return;
        }
        this._fin = (buf[0] & 128) === 128;
        this._opcode = buf[0] & 15;
        this._payloadLength = buf[1] & 127;
        if (this._opcode === 0) {
          if (compressed) {
            const error = this.createError(
              RangeError,
              "RSV1 must be clear",
              true,
              1002,
              "WS_ERR_UNEXPECTED_RSV_1"
            );
            cb(error);
            return;
          }
          if (!this._fragmented) {
            const error = this.createError(
              RangeError,
              "invalid opcode 0",
              true,
              1002,
              "WS_ERR_INVALID_OPCODE"
            );
            cb(error);
            return;
          }
          this._opcode = this._fragmented;
        } else if (this._opcode === 1 || this._opcode === 2) {
          if (this._fragmented) {
            const error = this.createError(
              RangeError,
              `invalid opcode ${this._opcode}`,
              true,
              1002,
              "WS_ERR_INVALID_OPCODE"
            );
            cb(error);
            return;
          }
          this._compressed = compressed;
        } else if (this._opcode > 7 && this._opcode < 11) {
          if (!this._fin) {
            const error = this.createError(
              RangeError,
              "FIN must be set",
              true,
              1002,
              "WS_ERR_EXPECTED_FIN"
            );
            cb(error);
            return;
          }
          if (compressed) {
            const error = this.createError(
              RangeError,
              "RSV1 must be clear",
              true,
              1002,
              "WS_ERR_UNEXPECTED_RSV_1"
            );
            cb(error);
            return;
          }
          if (this._payloadLength > 125 || this._opcode === 8 && this._payloadLength === 1) {
            const error = this.createError(
              RangeError,
              `invalid payload length ${this._payloadLength}`,
              true,
              1002,
              "WS_ERR_INVALID_CONTROL_PAYLOAD_LENGTH"
            );
            cb(error);
            return;
          }
        } else {
          const error = this.createError(
            RangeError,
            `invalid opcode ${this._opcode}`,
            true,
            1002,
            "WS_ERR_INVALID_OPCODE"
          );
          cb(error);
          return;
        }
        if (!this._fin && !this._fragmented) this._fragmented = this._opcode;
        this._masked = (buf[1] & 128) === 128;
        if (this._isServer) {
          if (!this._masked) {
            const error = this.createError(
              RangeError,
              "MASK must be set",
              true,
              1002,
              "WS_ERR_EXPECTED_MASK"
            );
            cb(error);
            return;
          }
        } else if (this._masked) {
          const error = this.createError(
            RangeError,
            "MASK must be clear",
            true,
            1002,
            "WS_ERR_UNEXPECTED_MASK"
          );
          cb(error);
          return;
        }
        if (this._payloadLength === 126) this._state = GET_PAYLOAD_LENGTH_16;
        else if (this._payloadLength === 127) this._state = GET_PAYLOAD_LENGTH_64;
        else this.haveLength(cb);
      }
      /**
       * Gets extended payload length (7+16).
       *
       * @param {Function} cb Callback
       * @private
       */
      getPayloadLength16(cb) {
        if (this._bufferedBytes < 2) {
          this._loop = false;
          return;
        }
        this._payloadLength = this.consume(2).readUInt16BE(0);
        this.haveLength(cb);
      }
      /**
       * Gets extended payload length (7+64).
       *
       * @param {Function} cb Callback
       * @private
       */
      getPayloadLength64(cb) {
        if (this._bufferedBytes < 8) {
          this._loop = false;
          return;
        }
        const buf = this.consume(8);
        const num = buf.readUInt32BE(0);
        if (num > Math.pow(2, 53 - 32) - 1) {
          const error = this.createError(
            RangeError,
            "Unsupported WebSocket frame: payload length > 2^53 - 1",
            false,
            1009,
            "WS_ERR_UNSUPPORTED_DATA_PAYLOAD_LENGTH"
          );
          cb(error);
          return;
        }
        this._payloadLength = num * Math.pow(2, 32) + buf.readUInt32BE(4);
        this.haveLength(cb);
      }
      /**
       * Payload length has been read.
       *
       * @param {Function} cb Callback
       * @private
       */
      haveLength(cb) {
        if (this._payloadLength && this._opcode < 8) {
          this._totalPayloadLength += this._payloadLength;
          if (this._totalPayloadLength > this._maxPayload && this._maxPayload > 0) {
            const error = this.createError(
              RangeError,
              "Max payload size exceeded",
              false,
              1009,
              "WS_ERR_UNSUPPORTED_MESSAGE_LENGTH"
            );
            cb(error);
            return;
          }
        }
        if (this._masked) this._state = GET_MASK;
        else this._state = GET_DATA;
      }
      /**
       * Reads mask bytes.
       *
       * @private
       */
      getMask() {
        if (this._bufferedBytes < 4) {
          this._loop = false;
          return;
        }
        this._mask = this.consume(4);
        this._state = GET_DATA;
      }
      /**
       * Reads data bytes.
       *
       * @param {Function} cb Callback
       * @private
       */
      getData(cb) {
        let data = EMPTY_BUFFER;
        if (this._payloadLength) {
          if (this._bufferedBytes < this._payloadLength) {
            this._loop = false;
            return;
          }
          data = this.consume(this._payloadLength);
          if (this._masked && (this._mask[0] | this._mask[1] | this._mask[2] | this._mask[3]) !== 0) {
            unmask(data, this._mask);
          }
        }
        if (this._opcode > 7) {
          this.controlMessage(data, cb);
          return;
        }
        if (this._maxFragments > 0 && ++this._numFragments > this._maxFragments) {
          const error = this.createError(
            RangeError,
            "Too many message fragments",
            false,
            1008,
            "WS_ERR_TOO_MANY_BUFFERED_PARTS"
          );
          cb(error);
          return;
        }
        if (this._compressed) {
          this._state = INFLATING;
          this.decompress(data, cb);
          return;
        }
        if (data.length) {
          this._messageLength = this._totalPayloadLength;
          this._fragments.push(data);
        }
        this.dataMessage(cb);
      }
      /**
       * Decompresses data.
       *
       * @param {Buffer} data Compressed data
       * @param {Function} cb Callback
       * @private
       */
      decompress(data, cb) {
        const perMessageDeflate = this._extensions[PerMessageDeflate2.extensionName];
        perMessageDeflate.decompress(data, this._fin, (err, buf) => {
          if (err) return cb(err);
          if (buf.length) {
            this._messageLength += buf.length;
            if (this._messageLength > this._maxPayload && this._maxPayload > 0) {
              const error = this.createError(
                RangeError,
                "Max payload size exceeded",
                false,
                1009,
                "WS_ERR_UNSUPPORTED_MESSAGE_LENGTH"
              );
              cb(error);
              return;
            }
            this._fragments.push(buf);
          }
          this.dataMessage(cb);
          if (this._state === GET_INFO) this.startLoop(cb);
        });
      }
      /**
       * Handles a data message.
       *
       * @param {Function} cb Callback
       * @private
       */
      dataMessage(cb) {
        if (!this._fin) {
          this._state = GET_INFO;
          return;
        }
        const messageLength = this._messageLength;
        const fragments = this._fragments;
        this._totalPayloadLength = 0;
        this._messageLength = 0;
        this._fragmented = 0;
        this._numFragments = 0;
        this._fragments = [];
        if (this._opcode === 2) {
          let data;
          if (this._binaryType === "nodebuffer") {
            data = concat(fragments, messageLength);
          } else if (this._binaryType === "arraybuffer") {
            data = toArrayBuffer(concat(fragments, messageLength));
          } else if (this._binaryType === "blob") {
            data = new Blob(fragments);
          } else {
            data = fragments;
          }
          if (this._allowSynchronousEvents) {
            this.emit("message", data, true);
            this._state = GET_INFO;
          } else {
            this._state = DEFER_EVENT;
            setImmediate(() => {
              this.emit("message", data, true);
              this._state = GET_INFO;
              this.startLoop(cb);
            });
          }
        } else {
          const buf = concat(fragments, messageLength);
          if (!this._skipUTF8Validation && !isValidUTF8(buf)) {
            const error = this.createError(
              Error,
              "invalid UTF-8 sequence",
              true,
              1007,
              "WS_ERR_INVALID_UTF8"
            );
            cb(error);
            return;
          }
          if (this._state === INFLATING || this._allowSynchronousEvents) {
            this.emit("message", buf, false);
            this._state = GET_INFO;
          } else {
            this._state = DEFER_EVENT;
            setImmediate(() => {
              this.emit("message", buf, false);
              this._state = GET_INFO;
              this.startLoop(cb);
            });
          }
        }
      }
      /**
       * Handles a control message.
       *
       * @param {Buffer} data Data to handle
       * @return {(Error|RangeError|undefined)} A possible error
       * @private
       */
      controlMessage(data, cb) {
        if (this._opcode === 8) {
          if (data.length === 0) {
            this._loop = false;
            this.emit("conclude", 1005, EMPTY_BUFFER);
            this.end();
          } else {
            const code = data.readUInt16BE(0);
            if (!isValidStatusCode(code)) {
              const error = this.createError(
                RangeError,
                `invalid status code ${code}`,
                true,
                1002,
                "WS_ERR_INVALID_CLOSE_CODE"
              );
              cb(error);
              return;
            }
            const buf = new FastBuffer(
              data.buffer,
              data.byteOffset + 2,
              data.length - 2
            );
            if (!this._skipUTF8Validation && !isValidUTF8(buf)) {
              const error = this.createError(
                Error,
                "invalid UTF-8 sequence",
                true,
                1007,
                "WS_ERR_INVALID_UTF8"
              );
              cb(error);
              return;
            }
            this._loop = false;
            this.emit("conclude", code, buf);
            this.end();
          }
          this._state = GET_INFO;
          return;
        }
        if (this._allowSynchronousEvents) {
          this.emit(this._opcode === 9 ? "ping" : "pong", data);
          this._state = GET_INFO;
        } else {
          this._state = DEFER_EVENT;
          setImmediate(() => {
            this.emit(this._opcode === 9 ? "ping" : "pong", data);
            this._state = GET_INFO;
            this.startLoop(cb);
          });
        }
      }
      /**
       * Builds an error object.
       *
       * @param {function(new:Error|RangeError)} ErrorCtor The error constructor
       * @param {String} message The error message
       * @param {Boolean} prefix Specifies whether or not to add a default prefix to
       *     `message`
       * @param {Number} statusCode The status code
       * @param {String} errorCode The exposed error code
       * @return {(Error|RangeError)} The error
       * @private
       */
      createError(ErrorCtor, message, prefix, statusCode, errorCode) {
        this._loop = false;
        this._errored = true;
        const err = new ErrorCtor(
          prefix ? `Invalid WebSocket frame: ${message}` : message
        );
        Error.captureStackTrace(err, this.createError);
        err.code = errorCode;
        err[kStatusCode] = statusCode;
        return err;
      }
    };
    module2.exports = Receiver2;
  }
});

// node_modules/ws/lib/sender.js
var require_sender = __commonJS({
  "node_modules/ws/lib/sender.js"(exports2, module2) {
    "use strict";
    var { Duplex } = require("stream");
    var { randomFillSync: randomFillSync2 } = require("crypto");
    var {
      types: { isUint8Array }
    } = require("util");
    var PerMessageDeflate2 = require_permessage_deflate();
    var { EMPTY_BUFFER, kWebSocket, NOOP } = require_constants();
    var { isBlob, isValidStatusCode } = require_validation();
    var { mask: applyMask, toBuffer } = require_buffer_util();
    var kByteLength = /* @__PURE__ */ Symbol("kByteLength");
    var maskBuffer = Buffer.alloc(4);
    var RANDOM_POOL_SIZE = 8 * 1024;
    var randomPool;
    var randomPoolPointer = RANDOM_POOL_SIZE;
    var DEFAULT = 0;
    var DEFLATING = 1;
    var GET_BLOB_DATA = 2;
    var Sender2 = class _Sender {
      /**
       * Creates a Sender instance.
       *
       * @param {Duplex} socket The connection socket
       * @param {Object} [extensions] An object containing the negotiated extensions
       * @param {Function} [generateMask] The function used to generate the masking
       *     key
       */
      constructor(socket, extensions, generateMask) {
        this._extensions = extensions || {};
        if (generateMask) {
          this._generateMask = generateMask;
          this._maskBuffer = Buffer.alloc(4);
        }
        this._socket = socket;
        this._firstFragment = true;
        this._compress = false;
        this._bufferedBytes = 0;
        this._queue = [];
        this._state = DEFAULT;
        this.onerror = NOOP;
        this[kWebSocket] = void 0;
      }
      /**
       * Frames a piece of data according to the HyBi WebSocket protocol.
       *
       * @param {(Buffer|String)} data The data to frame
       * @param {Object} options Options object
       * @param {Boolean} [options.fin=false] Specifies whether or not to set the
       *     FIN bit
       * @param {Function} [options.generateMask] The function used to generate the
       *     masking key
       * @param {Boolean} [options.mask=false] Specifies whether or not to mask
       *     `data`
       * @param {Buffer} [options.maskBuffer] The buffer used to store the masking
       *     key
       * @param {Number} options.opcode The opcode
       * @param {Boolean} [options.readOnly=false] Specifies whether `data` can be
       *     modified
       * @param {Boolean} [options.rsv1=false] Specifies whether or not to set the
       *     RSV1 bit
       * @return {(Buffer|String)[]} The framed data
       * @public
       */
      static frame(data, options) {
        let mask;
        let merge = false;
        let offset = 2;
        let skipMasking = false;
        if (options.mask) {
          mask = options.maskBuffer || maskBuffer;
          if (options.generateMask) {
            options.generateMask(mask);
          } else {
            if (randomPoolPointer === RANDOM_POOL_SIZE) {
              if (randomPool === void 0) {
                randomPool = Buffer.alloc(RANDOM_POOL_SIZE);
              }
              randomFillSync2(randomPool, 0, RANDOM_POOL_SIZE);
              randomPoolPointer = 0;
            }
            mask[0] = randomPool[randomPoolPointer++];
            mask[1] = randomPool[randomPoolPointer++];
            mask[2] = randomPool[randomPoolPointer++];
            mask[3] = randomPool[randomPoolPointer++];
          }
          skipMasking = (mask[0] | mask[1] | mask[2] | mask[3]) === 0;
          offset = 6;
        }
        let dataLength;
        if (typeof data === "string") {
          if ((!options.mask || skipMasking) && options[kByteLength] !== void 0) {
            dataLength = options[kByteLength];
          } else {
            data = Buffer.from(data);
            dataLength = data.length;
          }
        } else {
          dataLength = data.length;
          merge = options.mask && options.readOnly && !skipMasking;
        }
        let payloadLength = dataLength;
        if (dataLength >= 65536) {
          offset += 8;
          payloadLength = 127;
        } else if (dataLength > 125) {
          offset += 2;
          payloadLength = 126;
        }
        const target = Buffer.allocUnsafe(merge ? dataLength + offset : offset);
        target[0] = options.fin ? options.opcode | 128 : options.opcode;
        if (options.rsv1) target[0] |= 64;
        target[1] = payloadLength;
        if (payloadLength === 126) {
          target.writeUInt16BE(dataLength, 2);
        } else if (payloadLength === 127) {
          target[2] = target[3] = 0;
          target.writeUIntBE(dataLength, 4, 6);
        }
        if (!options.mask) return [target, data];
        target[1] |= 128;
        target[offset - 4] = mask[0];
        target[offset - 3] = mask[1];
        target[offset - 2] = mask[2];
        target[offset - 1] = mask[3];
        if (skipMasking) return [target, data];
        if (merge) {
          applyMask(data, mask, target, offset, dataLength);
          return [target];
        }
        applyMask(data, mask, data, 0, dataLength);
        return [target, data];
      }
      /**
       * Sends a close message to the other peer.
       *
       * @param {Number} [code] The status code component of the body
       * @param {(String|Buffer)} [data] The message component of the body
       * @param {Boolean} [mask=false] Specifies whether or not to mask the message
       * @param {Function} [cb] Callback
       * @public
       */
      close(code, data, mask, cb) {
        let buf;
        if (code === void 0) {
          buf = EMPTY_BUFFER;
        } else if (typeof code !== "number" || !isValidStatusCode(code)) {
          throw new TypeError("First argument must be a valid error code number");
        } else if (data === void 0 || !data.length) {
          buf = Buffer.allocUnsafe(2);
          buf.writeUInt16BE(code, 0);
        } else {
          const length = Buffer.byteLength(data);
          if (length > 123) {
            throw new RangeError("The message must not be greater than 123 bytes");
          }
          buf = Buffer.allocUnsafe(2 + length);
          buf.writeUInt16BE(code, 0);
          if (typeof data === "string") {
            buf.write(data, 2);
          } else if (isUint8Array(data)) {
            buf.set(data, 2);
          } else {
            throw new TypeError("Second argument must be a string or a Uint8Array");
          }
        }
        const options = {
          [kByteLength]: buf.length,
          fin: true,
          generateMask: this._generateMask,
          mask,
          maskBuffer: this._maskBuffer,
          opcode: 8,
          readOnly: false,
          rsv1: false
        };
        if (this._state !== DEFAULT) {
          this.enqueue([this.dispatch, buf, false, options, cb]);
        } else {
          this.sendFrame(_Sender.frame(buf, options), cb);
        }
      }
      /**
       * Sends a ping message to the other peer.
       *
       * @param {*} data The message to send
       * @param {Boolean} [mask=false] Specifies whether or not to mask `data`
       * @param {Function} [cb] Callback
       * @public
       */
      ping(data, mask, cb) {
        let byteLength;
        let readOnly;
        if (typeof data === "string") {
          byteLength = Buffer.byteLength(data);
          readOnly = false;
        } else if (isBlob(data)) {
          byteLength = data.size;
          readOnly = false;
        } else {
          data = toBuffer(data);
          byteLength = data.length;
          readOnly = toBuffer.readOnly;
        }
        if (byteLength > 125) {
          throw new RangeError("The data size must not be greater than 125 bytes");
        }
        const options = {
          [kByteLength]: byteLength,
          fin: true,
          generateMask: this._generateMask,
          mask,
          maskBuffer: this._maskBuffer,
          opcode: 9,
          readOnly,
          rsv1: false
        };
        if (isBlob(data)) {
          if (this._state !== DEFAULT) {
            this.enqueue([this.getBlobData, data, false, options, cb]);
          } else {
            this.getBlobData(data, false, options, cb);
          }
        } else if (this._state !== DEFAULT) {
          this.enqueue([this.dispatch, data, false, options, cb]);
        } else {
          this.sendFrame(_Sender.frame(data, options), cb);
        }
      }
      /**
       * Sends a pong message to the other peer.
       *
       * @param {*} data The message to send
       * @param {Boolean} [mask=false] Specifies whether or not to mask `data`
       * @param {Function} [cb] Callback
       * @public
       */
      pong(data, mask, cb) {
        let byteLength;
        let readOnly;
        if (typeof data === "string") {
          byteLength = Buffer.byteLength(data);
          readOnly = false;
        } else if (isBlob(data)) {
          byteLength = data.size;
          readOnly = false;
        } else {
          data = toBuffer(data);
          byteLength = data.length;
          readOnly = toBuffer.readOnly;
        }
        if (byteLength > 125) {
          throw new RangeError("The data size must not be greater than 125 bytes");
        }
        const options = {
          [kByteLength]: byteLength,
          fin: true,
          generateMask: this._generateMask,
          mask,
          maskBuffer: this._maskBuffer,
          opcode: 10,
          readOnly,
          rsv1: false
        };
        if (isBlob(data)) {
          if (this._state !== DEFAULT) {
            this.enqueue([this.getBlobData, data, false, options, cb]);
          } else {
            this.getBlobData(data, false, options, cb);
          }
        } else if (this._state !== DEFAULT) {
          this.enqueue([this.dispatch, data, false, options, cb]);
        } else {
          this.sendFrame(_Sender.frame(data, options), cb);
        }
      }
      /**
       * Sends a data message to the other peer.
       *
       * @param {*} data The message to send
       * @param {Object} options Options object
       * @param {Boolean} [options.binary=false] Specifies whether `data` is binary
       *     or text
       * @param {Boolean} [options.compress=false] Specifies whether or not to
       *     compress `data`
       * @param {Boolean} [options.fin=false] Specifies whether the fragment is the
       *     last one
       * @param {Boolean} [options.mask=false] Specifies whether or not to mask
       *     `data`
       * @param {Function} [cb] Callback
       * @public
       */
      send(data, options, cb) {
        const perMessageDeflate = this._extensions[PerMessageDeflate2.extensionName];
        let opcode = options.binary ? 2 : 1;
        let rsv1 = options.compress;
        let byteLength;
        let readOnly;
        if (typeof data === "string") {
          byteLength = Buffer.byteLength(data);
          readOnly = false;
        } else if (isBlob(data)) {
          byteLength = data.size;
          readOnly = false;
        } else {
          data = toBuffer(data);
          byteLength = data.length;
          readOnly = toBuffer.readOnly;
        }
        if (this._firstFragment) {
          this._firstFragment = false;
          if (rsv1 && perMessageDeflate && perMessageDeflate.params[perMessageDeflate._isServer ? "server_no_context_takeover" : "client_no_context_takeover"]) {
            rsv1 = byteLength >= perMessageDeflate._threshold;
          }
          this._compress = rsv1;
        } else {
          rsv1 = false;
          opcode = 0;
        }
        if (options.fin) this._firstFragment = true;
        const opts = {
          [kByteLength]: byteLength,
          fin: options.fin,
          generateMask: this._generateMask,
          mask: options.mask,
          maskBuffer: this._maskBuffer,
          opcode,
          readOnly,
          rsv1
        };
        if (isBlob(data)) {
          if (this._state !== DEFAULT) {
            this.enqueue([this.getBlobData, data, this._compress, opts, cb]);
          } else {
            this.getBlobData(data, this._compress, opts, cb);
          }
        } else if (this._state !== DEFAULT) {
          this.enqueue([this.dispatch, data, this._compress, opts, cb]);
        } else {
          this.dispatch(data, this._compress, opts, cb);
        }
      }
      /**
       * Gets the contents of a blob as binary data.
       *
       * @param {Blob} blob The blob
       * @param {Boolean} [compress=false] Specifies whether or not to compress
       *     the data
       * @param {Object} options Options object
       * @param {Boolean} [options.fin=false] Specifies whether or not to set the
       *     FIN bit
       * @param {Function} [options.generateMask] The function used to generate the
       *     masking key
       * @param {Boolean} [options.mask=false] Specifies whether or not to mask
       *     `data`
       * @param {Buffer} [options.maskBuffer] The buffer used to store the masking
       *     key
       * @param {Number} options.opcode The opcode
       * @param {Boolean} [options.readOnly=false] Specifies whether `data` can be
       *     modified
       * @param {Boolean} [options.rsv1=false] Specifies whether or not to set the
       *     RSV1 bit
       * @param {Function} [cb] Callback
       * @private
       */
      getBlobData(blob, compress, options, cb) {
        this._bufferedBytes += options[kByteLength];
        this._state = GET_BLOB_DATA;
        blob.arrayBuffer().then((arrayBuffer) => {
          if (this._socket.destroyed) {
            const err = new Error(
              "The socket was closed while the blob was being read"
            );
            process.nextTick(callCallbacks, this, err, cb);
            return;
          }
          this._bufferedBytes -= options[kByteLength];
          const data = toBuffer(arrayBuffer);
          if (!compress) {
            this._state = DEFAULT;
            this.sendFrame(_Sender.frame(data, options), cb);
            this.dequeue();
          } else {
            this.dispatch(data, compress, options, cb);
          }
        }).catch((err) => {
          process.nextTick(onError, this, err, cb);
        });
      }
      /**
       * Dispatches a message.
       *
       * @param {(Buffer|String)} data The message to send
       * @param {Boolean} [compress=false] Specifies whether or not to compress
       *     `data`
       * @param {Object} options Options object
       * @param {Boolean} [options.fin=false] Specifies whether or not to set the
       *     FIN bit
       * @param {Function} [options.generateMask] The function used to generate the
       *     masking key
       * @param {Boolean} [options.mask=false] Specifies whether or not to mask
       *     `data`
       * @param {Buffer} [options.maskBuffer] The buffer used to store the masking
       *     key
       * @param {Number} options.opcode The opcode
       * @param {Boolean} [options.readOnly=false] Specifies whether `data` can be
       *     modified
       * @param {Boolean} [options.rsv1=false] Specifies whether or not to set the
       *     RSV1 bit
       * @param {Function} [cb] Callback
       * @private
       */
      dispatch(data, compress, options, cb) {
        if (!compress) {
          this.sendFrame(_Sender.frame(data, options), cb);
          return;
        }
        const perMessageDeflate = this._extensions[PerMessageDeflate2.extensionName];
        this._bufferedBytes += options[kByteLength];
        this._state = DEFLATING;
        perMessageDeflate.compress(data, options.fin, (_, buf) => {
          if (this._socket.destroyed) {
            const err = new Error(
              "The socket was closed while data was being compressed"
            );
            callCallbacks(this, err, cb);
            return;
          }
          this._bufferedBytes -= options[kByteLength];
          this._state = DEFAULT;
          options.readOnly = false;
          this.sendFrame(_Sender.frame(buf, options), cb);
          this.dequeue();
        });
      }
      /**
       * Executes queued send operations.
       *
       * @private
       */
      dequeue() {
        while (this._state === DEFAULT && this._queue.length) {
          const params = this._queue.shift();
          this._bufferedBytes -= params[3][kByteLength];
          Reflect.apply(params[0], this, params.slice(1));
        }
      }
      /**
       * Enqueues a send operation.
       *
       * @param {Array} params Send operation parameters.
       * @private
       */
      enqueue(params) {
        this._bufferedBytes += params[3][kByteLength];
        this._queue.push(params);
      }
      /**
       * Sends a frame.
       *
       * @param {(Buffer | String)[]} list The frame to send
       * @param {Function} [cb] Callback
       * @private
       */
      sendFrame(list, cb) {
        if (list.length === 2) {
          this._socket.cork();
          this._socket.write(list[0]);
          this._socket.write(list[1], cb);
          this._socket.uncork();
        } else {
          this._socket.write(list[0], cb);
        }
      }
    };
    module2.exports = Sender2;
    function callCallbacks(sender, err, cb) {
      if (typeof cb === "function") cb(err);
      for (let i = 0; i < sender._queue.length; i++) {
        const params = sender._queue[i];
        const callback = params[params.length - 1];
        if (typeof callback === "function") callback(err);
      }
    }
    function onError(sender, err, cb) {
      callCallbacks(sender, err, cb);
      sender.onerror(err);
    }
  }
});

// node_modules/ws/lib/event-target.js
var require_event_target = __commonJS({
  "node_modules/ws/lib/event-target.js"(exports2, module2) {
    "use strict";
    var { kForOnEventAttribute, kListener } = require_constants();
    var kCode = /* @__PURE__ */ Symbol("kCode");
    var kData = /* @__PURE__ */ Symbol("kData");
    var kError = /* @__PURE__ */ Symbol("kError");
    var kMessage = /* @__PURE__ */ Symbol("kMessage");
    var kReason = /* @__PURE__ */ Symbol("kReason");
    var kTarget = /* @__PURE__ */ Symbol("kTarget");
    var kType = /* @__PURE__ */ Symbol("kType");
    var kWasClean = /* @__PURE__ */ Symbol("kWasClean");
    var Event = class {
      /**
       * Create a new `Event`.
       *
       * @param {String} type The name of the event
       * @throws {TypeError} If the `type` argument is not specified
       */
      constructor(type) {
        this[kTarget] = null;
        this[kType] = type;
      }
      /**
       * @type {*}
       */
      get target() {
        return this[kTarget];
      }
      /**
       * @type {String}
       */
      get type() {
        return this[kType];
      }
    };
    Object.defineProperty(Event.prototype, "target", { enumerable: true });
    Object.defineProperty(Event.prototype, "type", { enumerable: true });
    var CloseEvent = class extends Event {
      /**
       * Create a new `CloseEvent`.
       *
       * @param {String} type The name of the event
       * @param {Object} [options] A dictionary object that allows for setting
       *     attributes via object members of the same name
       * @param {Number} [options.code=0] The status code explaining why the
       *     connection was closed
       * @param {String} [options.reason=''] A human-readable string explaining why
       *     the connection was closed
       * @param {Boolean} [options.wasClean=false] Indicates whether or not the
       *     connection was cleanly closed
       */
      constructor(type, options = {}) {
        super(type);
        this[kCode] = options.code === void 0 ? 0 : options.code;
        this[kReason] = options.reason === void 0 ? "" : options.reason;
        this[kWasClean] = options.wasClean === void 0 ? false : options.wasClean;
      }
      /**
       * @type {Number}
       */
      get code() {
        return this[kCode];
      }
      /**
       * @type {String}
       */
      get reason() {
        return this[kReason];
      }
      /**
       * @type {Boolean}
       */
      get wasClean() {
        return this[kWasClean];
      }
    };
    Object.defineProperty(CloseEvent.prototype, "code", { enumerable: true });
    Object.defineProperty(CloseEvent.prototype, "reason", { enumerable: true });
    Object.defineProperty(CloseEvent.prototype, "wasClean", { enumerable: true });
    var ErrorEvent = class extends Event {
      /**
       * Create a new `ErrorEvent`.
       *
       * @param {String} type The name of the event
       * @param {Object} [options] A dictionary object that allows for setting
       *     attributes via object members of the same name
       * @param {*} [options.error=null] The error that generated this event
       * @param {String} [options.message=''] The error message
       */
      constructor(type, options = {}) {
        super(type);
        this[kError] = options.error === void 0 ? null : options.error;
        this[kMessage] = options.message === void 0 ? "" : options.message;
      }
      /**
       * @type {*}
       */
      get error() {
        return this[kError];
      }
      /**
       * @type {String}
       */
      get message() {
        return this[kMessage];
      }
    };
    Object.defineProperty(ErrorEvent.prototype, "error", { enumerable: true });
    Object.defineProperty(ErrorEvent.prototype, "message", { enumerable: true });
    var MessageEvent = class extends Event {
      /**
       * Create a new `MessageEvent`.
       *
       * @param {String} type The name of the event
       * @param {Object} [options] A dictionary object that allows for setting
       *     attributes via object members of the same name
       * @param {*} [options.data=null] The message content
       */
      constructor(type, options = {}) {
        super(type);
        this[kData] = options.data === void 0 ? null : options.data;
      }
      /**
       * @type {*}
       */
      get data() {
        return this[kData];
      }
    };
    Object.defineProperty(MessageEvent.prototype, "data", { enumerable: true });
    var EventTarget = {
      /**
       * Register an event listener.
       *
       * @param {String} type A string representing the event type to listen for
       * @param {(Function|Object)} handler The listener to add
       * @param {Object} [options] An options object specifies characteristics about
       *     the event listener
       * @param {Boolean} [options.once=false] A `Boolean` indicating that the
       *     listener should be invoked at most once after being added. If `true`,
       *     the listener would be automatically removed when invoked.
       * @public
       */
      addEventListener(type, handler, options = {}) {
        for (const listener of this.listeners(type)) {
          if (!options[kForOnEventAttribute] && listener[kListener] === handler && !listener[kForOnEventAttribute]) {
            return;
          }
        }
        let wrapper;
        if (type === "message") {
          wrapper = function onMessage(data, isBinary) {
            const event = new MessageEvent("message", {
              data: isBinary ? data : data.toString()
            });
            event[kTarget] = this;
            callListener(handler, this, event);
          };
        } else if (type === "close") {
          wrapper = function onClose(code, message) {
            const event = new CloseEvent("close", {
              code,
              reason: message.toString(),
              wasClean: this._closeFrameReceived && this._closeFrameSent
            });
            event[kTarget] = this;
            callListener(handler, this, event);
          };
        } else if (type === "error") {
          wrapper = function onError(error) {
            const event = new ErrorEvent("error", {
              error,
              message: error.message
            });
            event[kTarget] = this;
            callListener(handler, this, event);
          };
        } else if (type === "open") {
          wrapper = function onOpen() {
            const event = new Event("open");
            event[kTarget] = this;
            callListener(handler, this, event);
          };
        } else {
          return;
        }
        wrapper[kForOnEventAttribute] = !!options[kForOnEventAttribute];
        wrapper[kListener] = handler;
        if (options.once) {
          this.once(type, wrapper);
        } else {
          this.on(type, wrapper);
        }
      },
      /**
       * Remove an event listener.
       *
       * @param {String} type A string representing the event type to remove
       * @param {(Function|Object)} handler The listener to remove
       * @public
       */
      removeEventListener(type, handler) {
        for (const listener of this.listeners(type)) {
          if (listener[kListener] === handler && !listener[kForOnEventAttribute]) {
            this.removeListener(type, listener);
            break;
          }
        }
      }
    };
    module2.exports = {
      CloseEvent,
      ErrorEvent,
      Event,
      EventTarget,
      MessageEvent
    };
    function callListener(listener, thisArg, event) {
      if (typeof listener === "object" && listener.handleEvent) {
        listener.handleEvent.call(listener, event);
      } else {
        listener.call(thisArg, event);
      }
    }
  }
});

// node_modules/ws/lib/extension.js
var require_extension = __commonJS({
  "node_modules/ws/lib/extension.js"(exports2, module2) {
    "use strict";
    var { tokenChars } = require_validation();
    function push(dest, name, elem) {
      if (dest[name] === void 0) dest[name] = [elem];
      else dest[name].push(elem);
    }
    function parse(header) {
      const offers = /* @__PURE__ */ Object.create(null);
      let params = /* @__PURE__ */ Object.create(null);
      let mustUnescape = false;
      let isEscaping = false;
      let inQuotes = false;
      let extensionName;
      let paramName;
      let start = -1;
      let code = -1;
      let end = -1;
      let i = 0;
      for (; i < header.length; i++) {
        code = header.charCodeAt(i);
        if (extensionName === void 0) {
          if (end === -1 && tokenChars[code] === 1) {
            if (start === -1) start = i;
          } else if (i !== 0 && (code === 32 || code === 9)) {
            if (end === -1 && start !== -1) end = i;
          } else if (code === 59 || code === 44) {
            if (start === -1) {
              throw new SyntaxError(`Unexpected character at index ${i}`);
            }
            if (end === -1) end = i;
            const name = header.slice(start, end);
            if (code === 44) {
              push(offers, name, params);
              params = /* @__PURE__ */ Object.create(null);
            } else {
              extensionName = name;
            }
            start = end = -1;
          } else {
            throw new SyntaxError(`Unexpected character at index ${i}`);
          }
        } else if (paramName === void 0) {
          if (end === -1 && tokenChars[code] === 1) {
            if (start === -1) start = i;
          } else if (code === 32 || code === 9) {
            if (end === -1 && start !== -1) end = i;
          } else if (code === 59 || code === 44) {
            if (start === -1) {
              throw new SyntaxError(`Unexpected character at index ${i}`);
            }
            if (end === -1) end = i;
            push(params, header.slice(start, end), true);
            if (code === 44) {
              push(offers, extensionName, params);
              params = /* @__PURE__ */ Object.create(null);
              extensionName = void 0;
            }
            start = end = -1;
          } else if (code === 61 && start !== -1 && end === -1) {
            paramName = header.slice(start, i);
            start = end = -1;
          } else {
            throw new SyntaxError(`Unexpected character at index ${i}`);
          }
        } else {
          if (isEscaping) {
            if (tokenChars[code] !== 1) {
              throw new SyntaxError(`Unexpected character at index ${i}`);
            }
            if (start === -1) start = i;
            else if (!mustUnescape) mustUnescape = true;
            isEscaping = false;
          } else if (inQuotes) {
            if (tokenChars[code] === 1) {
              if (start === -1) start = i;
            } else if (code === 34 && start !== -1) {
              inQuotes = false;
              end = i;
            } else if (code === 92) {
              isEscaping = true;
            } else {
              throw new SyntaxError(`Unexpected character at index ${i}`);
            }
          } else if (code === 34 && header.charCodeAt(i - 1) === 61) {
            inQuotes = true;
          } else if (end === -1 && tokenChars[code] === 1) {
            if (start === -1) start = i;
          } else if (start !== -1 && (code === 32 || code === 9)) {
            if (end === -1) end = i;
          } else if (code === 59 || code === 44) {
            if (start === -1) {
              throw new SyntaxError(`Unexpected character at index ${i}`);
            }
            if (end === -1) end = i;
            let value = header.slice(start, end);
            if (mustUnescape) {
              value = value.replace(/\\/g, "");
              mustUnescape = false;
            }
            push(params, paramName, value);
            if (code === 44) {
              push(offers, extensionName, params);
              params = /* @__PURE__ */ Object.create(null);
              extensionName = void 0;
            }
            paramName = void 0;
            start = end = -1;
          } else {
            throw new SyntaxError(`Unexpected character at index ${i}`);
          }
        }
      }
      if (start === -1 || inQuotes || code === 32 || code === 9) {
        throw new SyntaxError("Unexpected end of input");
      }
      if (end === -1) end = i;
      const token = header.slice(start, end);
      if (extensionName === void 0) {
        push(offers, token, params);
      } else {
        if (paramName === void 0) {
          push(params, token, true);
        } else if (mustUnescape) {
          push(params, paramName, token.replace(/\\/g, ""));
        } else {
          push(params, paramName, token);
        }
        push(offers, extensionName, params);
      }
      return offers;
    }
    function format(extensions) {
      return Object.keys(extensions).map((extension2) => {
        let configurations = extensions[extension2];
        if (!Array.isArray(configurations)) configurations = [configurations];
        return configurations.map((params) => {
          return [extension2].concat(
            Object.keys(params).map((k) => {
              let values = params[k];
              if (!Array.isArray(values)) values = [values];
              return values.map((v) => v === true ? k : `${k}=${v}`).join("; ");
            })
          ).join("; ");
        }).join(", ");
      }).join(", ");
    }
    module2.exports = { format, parse };
  }
});

// node_modules/ws/lib/websocket.js
var require_websocket = __commonJS({
  "node_modules/ws/lib/websocket.js"(exports2, module2) {
    "use strict";
    var EventEmitter = require("events");
    var https = require("https");
    var http = require("http");
    var net2 = require("net");
    var tls = require("tls");
    var { randomBytes, createHash: createHash2 } = require("crypto");
    var { Duplex, Readable } = require("stream");
    var { URL } = require("url");
    var PerMessageDeflate2 = require_permessage_deflate();
    var Receiver2 = require_receiver();
    var Sender2 = require_sender();
    var { isBlob } = require_validation();
    var {
      BINARY_TYPES,
      CLOSE_TIMEOUT,
      EMPTY_BUFFER,
      GUID,
      kForOnEventAttribute,
      kListener,
      kStatusCode,
      kWebSocket,
      NOOP
    } = require_constants();
    var {
      EventTarget: { addEventListener, removeEventListener }
    } = require_event_target();
    var { format, parse } = require_extension();
    var { toBuffer } = require_buffer_util();
    var kAborted = /* @__PURE__ */ Symbol("kAborted");
    var protocolVersions = [8, 13];
    var readyStates = ["CONNECTING", "OPEN", "CLOSING", "CLOSED"];
    var subprotocolRegex = /^[!#$%&'*+\-.0-9A-Z^_`|a-z~]+$/;
    var WebSocket2 = class _WebSocket extends EventEmitter {
      /**
       * Create a new `WebSocket`.
       *
       * @param {(String|URL)} address The URL to which to connect
       * @param {(String|String[])} [protocols] The subprotocols
       * @param {Object} [options] Connection options
       */
      constructor(address, protocols, options) {
        super();
        this._binaryType = BINARY_TYPES[0];
        this._closeCode = 1006;
        this._closeFrameReceived = false;
        this._closeFrameSent = false;
        this._closeMessage = EMPTY_BUFFER;
        this._closeTimer = null;
        this._errorEmitted = false;
        this._extensions = {};
        this._paused = false;
        this._protocol = "";
        this._readyState = _WebSocket.CONNECTING;
        this._receiver = null;
        this._sender = null;
        this._socket = null;
        if (address !== null) {
          this._bufferedAmount = 0;
          this._isServer = false;
          this._redirects = 0;
          if (protocols === void 0) {
            if (!options || options.protocols === void 0) {
              protocols = [];
            } else if (Array.isArray(options.protocols)) {
              protocols = options.protocols;
            } else {
              protocols = [options.protocols];
            }
          } else if (!Array.isArray(protocols)) {
            if (typeof protocols === "object" && protocols !== null) {
              options = protocols;
              if (options.protocols === void 0) {
                protocols = [];
              } else if (Array.isArray(options.protocols)) {
                protocols = options.protocols;
              } else {
                protocols = [options.protocols];
              }
            } else {
              protocols = [protocols];
            }
          }
          initAsClient(this, address, protocols, options);
        } else {
          this._autoPong = options.autoPong;
          this._closeTimeout = options.closeTimeout;
          this._isServer = true;
        }
      }
      /**
       * For historical reasons, the custom "nodebuffer" type is used by the default
       * instead of "blob".
       *
       * @type {String}
       */
      get binaryType() {
        return this._binaryType;
      }
      set binaryType(type) {
        if (!BINARY_TYPES.includes(type)) return;
        this._binaryType = type;
        if (this._receiver) this._receiver._binaryType = type;
      }
      /**
       * @type {Number}
       */
      get bufferedAmount() {
        if (!this._socket) return this._bufferedAmount;
        return this._socket._writableState.length + this._sender._bufferedBytes;
      }
      /**
       * @type {String}
       */
      get extensions() {
        return Object.keys(this._extensions).join();
      }
      /**
       * @type {Boolean}
       */
      get isPaused() {
        return this._paused;
      }
      /**
       * @type {Function}
       */
      /* istanbul ignore next */
      get onclose() {
        return null;
      }
      /**
       * @type {Function}
       */
      /* istanbul ignore next */
      get onerror() {
        return null;
      }
      /**
       * @type {Function}
       */
      /* istanbul ignore next */
      get onopen() {
        return null;
      }
      /**
       * @type {Function}
       */
      /* istanbul ignore next */
      get onmessage() {
        return null;
      }
      /**
       * @type {String}
       */
      get protocol() {
        return this._protocol;
      }
      /**
       * @type {Number}
       */
      get readyState() {
        return this._readyState;
      }
      /**
       * @type {String}
       */
      get url() {
        return this._url;
      }
      /**
       * Set up the socket and the internal resources.
       *
       * @param {Duplex} socket The network socket between the server and client
       * @param {Buffer} head The first packet of the upgraded stream
       * @param {Object} options Options object
       * @param {Boolean} [options.allowSynchronousEvents=false] Specifies whether
       *     any of the `'message'`, `'ping'`, and `'pong'` events can be emitted
       *     multiple times in the same tick
       * @param {Function} [options.generateMask] The function used to generate the
       *     masking key
       * @param {Number} [options.maxBufferedChunks=0] The maximum number of
       *     buffered data chunks
       * @param {Number} [options.maxFragments=0] The maximum number of message
       *     fragments
       * @param {Number} [options.maxPayload=0] The maximum allowed message size
       * @param {Boolean} [options.skipUTF8Validation=false] Specifies whether or
       *     not to skip UTF-8 validation for text and close messages
       * @private
       */
      setSocket(socket, head, options) {
        const receiver = new Receiver2({
          allowSynchronousEvents: options.allowSynchronousEvents,
          binaryType: this.binaryType,
          extensions: this._extensions,
          isServer: this._isServer,
          maxBufferedChunks: options.maxBufferedChunks,
          maxFragments: options.maxFragments,
          maxPayload: options.maxPayload,
          skipUTF8Validation: options.skipUTF8Validation
        });
        const sender = new Sender2(socket, this._extensions, options.generateMask);
        this._receiver = receiver;
        this._sender = sender;
        this._socket = socket;
        receiver[kWebSocket] = this;
        sender[kWebSocket] = this;
        socket[kWebSocket] = this;
        receiver.on("conclude", receiverOnConclude);
        receiver.on("drain", receiverOnDrain);
        receiver.on("error", receiverOnError);
        receiver.on("message", receiverOnMessage);
        receiver.on("ping", receiverOnPing);
        receiver.on("pong", receiverOnPong);
        sender.onerror = senderOnError;
        if (socket.setTimeout) socket.setTimeout(0);
        if (socket.setNoDelay) socket.setNoDelay();
        if (head.length > 0) socket.unshift(head);
        socket.on("close", socketOnClose);
        socket.on("data", socketOnData);
        socket.on("end", socketOnEnd);
        socket.on("error", socketOnError);
        this._readyState = _WebSocket.OPEN;
        this.emit("open");
      }
      /**
       * Emit the `'close'` event.
       *
       * @private
       */
      emitClose() {
        if (!this._socket) {
          this._readyState = _WebSocket.CLOSED;
          this.emit("close", this._closeCode, this._closeMessage);
          return;
        }
        if (this._extensions[PerMessageDeflate2.extensionName]) {
          this._extensions[PerMessageDeflate2.extensionName].cleanup();
        }
        this._receiver.removeAllListeners();
        this._readyState = _WebSocket.CLOSED;
        this.emit("close", this._closeCode, this._closeMessage);
      }
      /**
       * Start a closing handshake.
       *
       *          +----------+   +-----------+   +----------+
       *     - - -|ws.close()|-->|close frame|-->|ws.close()|- - -
       *    |     +----------+   +-----------+   +----------+     |
       *          +----------+   +-----------+         |
       * CLOSING  |ws.close()|<--|close frame|<--+-----+       CLOSING
       *          +----------+   +-----------+   |
       *    |           |                        |   +---+        |
       *                +------------------------+-->|fin| - - - -
       *    |         +---+                      |   +---+
       *     - - - - -|fin|<---------------------+
       *              +---+
       *
       * @param {Number} [code] Status code explaining why the connection is closing
       * @param {(String|Buffer)} [data] The reason why the connection is
       *     closing
       * @public
       */
      close(code, data) {
        if (this.readyState === _WebSocket.CLOSED) return;
        if (this.readyState === _WebSocket.CONNECTING) {
          const msg = "WebSocket was closed before the connection was established";
          abortHandshake(this, this._req, msg);
          return;
        }
        if (this.readyState === _WebSocket.CLOSING) {
          if (this._closeFrameSent && (this._closeFrameReceived || this._receiver._writableState.errorEmitted)) {
            this._socket.end();
          }
          return;
        }
        this._sender.close(code, data, !this._isServer, (err) => {
          if (err) return;
          this._closeFrameSent = true;
          if (this._closeFrameReceived || this._receiver._writableState.errorEmitted) {
            this._socket.end();
          }
        });
        this._readyState = _WebSocket.CLOSING;
        setCloseTimer(this);
      }
      /**
       * Pause the socket.
       *
       * @public
       */
      pause() {
        if (this.readyState === _WebSocket.CONNECTING || this.readyState === _WebSocket.CLOSED) {
          return;
        }
        this._paused = true;
        this._socket.pause();
      }
      /**
       * Send a ping.
       *
       * @param {*} [data] The data to send
       * @param {Boolean} [mask] Indicates whether or not to mask `data`
       * @param {Function} [cb] Callback which is executed when the ping is sent
       * @public
       */
      ping(data, mask, cb) {
        if (this.readyState === _WebSocket.CONNECTING) {
          throw new Error("WebSocket is not open: readyState 0 (CONNECTING)");
        }
        if (typeof data === "function") {
          cb = data;
          data = mask = void 0;
        } else if (typeof mask === "function") {
          cb = mask;
          mask = void 0;
        }
        if (typeof data === "number") data = data.toString();
        if (this.readyState !== _WebSocket.OPEN) {
          sendAfterClose(this, data, cb);
          return;
        }
        if (mask === void 0) mask = !this._isServer;
        this._sender.ping(data || EMPTY_BUFFER, mask, cb);
      }
      /**
       * Send a pong.
       *
       * @param {*} [data] The data to send
       * @param {Boolean} [mask] Indicates whether or not to mask `data`
       * @param {Function} [cb] Callback which is executed when the pong is sent
       * @public
       */
      pong(data, mask, cb) {
        if (this.readyState === _WebSocket.CONNECTING) {
          throw new Error("WebSocket is not open: readyState 0 (CONNECTING)");
        }
        if (typeof data === "function") {
          cb = data;
          data = mask = void 0;
        } else if (typeof mask === "function") {
          cb = mask;
          mask = void 0;
        }
        if (typeof data === "number") data = data.toString();
        if (this.readyState !== _WebSocket.OPEN) {
          sendAfterClose(this, data, cb);
          return;
        }
        if (mask === void 0) mask = !this._isServer;
        this._sender.pong(data || EMPTY_BUFFER, mask, cb);
      }
      /**
       * Resume the socket.
       *
       * @public
       */
      resume() {
        if (this.readyState === _WebSocket.CONNECTING || this.readyState === _WebSocket.CLOSED) {
          return;
        }
        this._paused = false;
        if (!this._receiver._writableState.needDrain) this._socket.resume();
      }
      /**
       * Send a data message.
       *
       * @param {*} data The message to send
       * @param {Object} [options] Options object
       * @param {Boolean} [options.binary] Specifies whether `data` is binary or
       *     text
       * @param {Boolean} [options.compress] Specifies whether or not to compress
       *     `data`
       * @param {Boolean} [options.fin=true] Specifies whether the fragment is the
       *     last one
       * @param {Boolean} [options.mask] Specifies whether or not to mask `data`
       * @param {Function} [cb] Callback which is executed when data is written out
       * @public
       */
      send(data, options, cb) {
        if (this.readyState === _WebSocket.CONNECTING) {
          throw new Error("WebSocket is not open: readyState 0 (CONNECTING)");
        }
        if (typeof options === "function") {
          cb = options;
          options = {};
        }
        if (typeof data === "number") data = data.toString();
        if (this.readyState !== _WebSocket.OPEN) {
          sendAfterClose(this, data, cb);
          return;
        }
        const opts = {
          binary: typeof data !== "string",
          mask: !this._isServer,
          compress: true,
          fin: true,
          ...options
        };
        if (!this._extensions[PerMessageDeflate2.extensionName]) {
          opts.compress = false;
        }
        this._sender.send(data || EMPTY_BUFFER, opts, cb);
      }
      /**
       * Forcibly close the connection.
       *
       * @public
       */
      terminate() {
        if (this.readyState === _WebSocket.CLOSED) return;
        if (this.readyState === _WebSocket.CONNECTING) {
          const msg = "WebSocket was closed before the connection was established";
          abortHandshake(this, this._req, msg);
          return;
        }
        if (this._socket) {
          this._readyState = _WebSocket.CLOSING;
          this._socket.destroy();
        }
      }
    };
    Object.defineProperty(WebSocket2, "CONNECTING", {
      enumerable: true,
      value: readyStates.indexOf("CONNECTING")
    });
    Object.defineProperty(WebSocket2.prototype, "CONNECTING", {
      enumerable: true,
      value: readyStates.indexOf("CONNECTING")
    });
    Object.defineProperty(WebSocket2, "OPEN", {
      enumerable: true,
      value: readyStates.indexOf("OPEN")
    });
    Object.defineProperty(WebSocket2.prototype, "OPEN", {
      enumerable: true,
      value: readyStates.indexOf("OPEN")
    });
    Object.defineProperty(WebSocket2, "CLOSING", {
      enumerable: true,
      value: readyStates.indexOf("CLOSING")
    });
    Object.defineProperty(WebSocket2.prototype, "CLOSING", {
      enumerable: true,
      value: readyStates.indexOf("CLOSING")
    });
    Object.defineProperty(WebSocket2, "CLOSED", {
      enumerable: true,
      value: readyStates.indexOf("CLOSED")
    });
    Object.defineProperty(WebSocket2.prototype, "CLOSED", {
      enumerable: true,
      value: readyStates.indexOf("CLOSED")
    });
    [
      "binaryType",
      "bufferedAmount",
      "extensions",
      "isPaused",
      "protocol",
      "readyState",
      "url"
    ].forEach((property) => {
      Object.defineProperty(WebSocket2.prototype, property, { enumerable: true });
    });
    ["open", "error", "close", "message"].forEach((method) => {
      Object.defineProperty(WebSocket2.prototype, `on${method}`, {
        enumerable: true,
        get() {
          for (const listener of this.listeners(method)) {
            if (listener[kForOnEventAttribute]) return listener[kListener];
          }
          return null;
        },
        set(handler) {
          for (const listener of this.listeners(method)) {
            if (listener[kForOnEventAttribute]) {
              this.removeListener(method, listener);
              break;
            }
          }
          if (typeof handler !== "function") return;
          this.addEventListener(method, handler, {
            [kForOnEventAttribute]: true
          });
        }
      });
    });
    WebSocket2.prototype.addEventListener = addEventListener;
    WebSocket2.prototype.removeEventListener = removeEventListener;
    module2.exports = WebSocket2;
    function initAsClient(websocket, address, protocols, options) {
      const opts = {
        allowSynchronousEvents: true,
        autoPong: true,
        closeTimeout: CLOSE_TIMEOUT,
        protocolVersion: protocolVersions[1],
        maxBufferedChunks: 256 * 1024,
        maxFragments: 16 * 1024,
        maxPayload: 100 * 1024 * 1024,
        skipUTF8Validation: false,
        perMessageDeflate: true,
        followRedirects: false,
        maxRedirects: 10,
        ...options,
        socketPath: void 0,
        hostname: void 0,
        protocol: void 0,
        protocols: void 0,
        timeout: void 0,
        method: "GET",
        host: void 0,
        path: void 0,
        port: void 0
      };
      websocket._autoPong = opts.autoPong;
      websocket._closeTimeout = opts.closeTimeout;
      if (!protocolVersions.includes(opts.protocolVersion)) {
        throw new RangeError(
          `Unsupported protocol version: ${opts.protocolVersion} (supported versions: ${protocolVersions.join(", ")})`
        );
      }
      let parsedUrl;
      if (address instanceof URL) {
        parsedUrl = address;
      } else {
        try {
          parsedUrl = new URL(address);
        } catch {
          throw new SyntaxError(`Invalid URL: ${address}`);
        }
      }
      if (parsedUrl.protocol === "http:") {
        parsedUrl.protocol = "ws:";
      } else if (parsedUrl.protocol === "https:") {
        parsedUrl.protocol = "wss:";
      }
      websocket._url = parsedUrl.href;
      const isSecure = parsedUrl.protocol === "wss:";
      const isIpcUrl = parsedUrl.protocol === "ws+unix:";
      let invalidUrlMessage;
      if (parsedUrl.protocol !== "ws:" && !isSecure && !isIpcUrl) {
        invalidUrlMessage = `The URL's protocol must be one of "ws:", "wss:", "http:", "https:", or "ws+unix:"`;
      } else if (isIpcUrl && !parsedUrl.pathname) {
        invalidUrlMessage = "The URL's pathname is empty";
      } else if (parsedUrl.hash) {
        invalidUrlMessage = "The URL contains a fragment identifier";
      }
      if (invalidUrlMessage) {
        const err = new SyntaxError(invalidUrlMessage);
        if (websocket._redirects === 0) {
          throw err;
        } else {
          emitErrorAndClose(websocket, err);
          return;
        }
      }
      const defaultPort = isSecure ? 443 : 80;
      const key = randomBytes(16).toString("base64");
      const request = isSecure ? https.request : http.request;
      const protocolSet = /* @__PURE__ */ new Set();
      let perMessageDeflate;
      opts.createConnection = opts.createConnection || (isSecure ? tlsConnect : netConnect);
      opts.defaultPort = opts.defaultPort || defaultPort;
      opts.port = parsedUrl.port || defaultPort;
      opts.host = parsedUrl.hostname.startsWith("[") ? parsedUrl.hostname.slice(1, -1) : parsedUrl.hostname;
      opts.headers = {
        ...opts.headers,
        "Sec-WebSocket-Version": opts.protocolVersion,
        "Sec-WebSocket-Key": key,
        Connection: "Upgrade",
        Upgrade: "websocket"
      };
      opts.path = parsedUrl.pathname + parsedUrl.search;
      opts.timeout = opts.handshakeTimeout;
      if (opts.perMessageDeflate) {
        perMessageDeflate = new PerMessageDeflate2({
          ...opts.perMessageDeflate,
          isServer: false,
          maxPayload: opts.maxPayload
        });
        opts.headers["Sec-WebSocket-Extensions"] = format({
          [PerMessageDeflate2.extensionName]: perMessageDeflate.offer()
        });
      }
      if (protocols.length) {
        for (const protocol of protocols) {
          if (typeof protocol !== "string" || !subprotocolRegex.test(protocol) || protocolSet.has(protocol)) {
            throw new SyntaxError(
              "An invalid or duplicated subprotocol was specified"
            );
          }
          protocolSet.add(protocol);
        }
        opts.headers["Sec-WebSocket-Protocol"] = protocols.join(",");
      }
      if (opts.origin) {
        if (opts.protocolVersion < 13) {
          opts.headers["Sec-WebSocket-Origin"] = opts.origin;
        } else {
          opts.headers.Origin = opts.origin;
        }
      }
      if (parsedUrl.username || parsedUrl.password) {
        opts.auth = `${parsedUrl.username}:${parsedUrl.password}`;
      }
      if (isIpcUrl) {
        const parts = opts.path.split(":");
        opts.socketPath = parts[0];
        opts.path = parts[1];
      }
      let req;
      if (opts.followRedirects) {
        if (websocket._redirects === 0) {
          websocket._originalIpc = isIpcUrl;
          websocket._originalSecure = isSecure;
          websocket._originalHostOrSocketPath = isIpcUrl ? opts.socketPath : parsedUrl.host;
          const headers = options && options.headers;
          options = { ...options, headers: {} };
          if (headers) {
            for (const [key2, value] of Object.entries(headers)) {
              options.headers[key2.toLowerCase()] = value;
            }
          }
        } else if (websocket.listenerCount("redirect") === 0) {
          const isSameHost = isIpcUrl ? websocket._originalIpc ? opts.socketPath === websocket._originalHostOrSocketPath : false : websocket._originalIpc ? false : parsedUrl.host === websocket._originalHostOrSocketPath;
          if (!isSameHost || websocket._originalSecure && !isSecure) {
            delete opts.headers.authorization;
            delete opts.headers.cookie;
            if (!isSameHost) delete opts.headers.host;
            opts.auth = void 0;
          }
        }
        if (opts.auth && !options.headers.authorization) {
          options.headers.authorization = "Basic " + Buffer.from(opts.auth).toString("base64");
        }
        req = websocket._req = request(opts);
        if (websocket._redirects) {
          websocket.emit("redirect", websocket.url, req);
        }
      } else {
        req = websocket._req = request(opts);
      }
      if (opts.timeout) {
        req.on("timeout", () => {
          abortHandshake(websocket, req, "Opening handshake has timed out");
        });
      }
      req.on("error", (err) => {
        if (req === null || req[kAborted]) return;
        req = websocket._req = null;
        emitErrorAndClose(websocket, err);
      });
      req.on("response", (res) => {
        const location = res.headers.location;
        const statusCode = res.statusCode;
        if (location && opts.followRedirects && statusCode >= 300 && statusCode < 400) {
          if (++websocket._redirects > opts.maxRedirects) {
            abortHandshake(websocket, req, "Maximum redirects exceeded");
            return;
          }
          req.abort();
          let addr;
          try {
            addr = new URL(location, address);
          } catch (e) {
            const err = new SyntaxError(`Invalid URL: ${location}`);
            emitErrorAndClose(websocket, err);
            return;
          }
          initAsClient(websocket, addr, protocols, options);
        } else if (!websocket.emit("unexpected-response", req, res)) {
          abortHandshake(
            websocket,
            req,
            `Unexpected server response: ${res.statusCode}`
          );
        }
      });
      req.on("upgrade", (res, socket, head) => {
        websocket.emit("upgrade", res);
        if (websocket.readyState !== WebSocket2.CONNECTING) return;
        req = websocket._req = null;
        const upgrade = res.headers.upgrade;
        if (upgrade === void 0 || upgrade.toLowerCase() !== "websocket") {
          abortHandshake(websocket, socket, "Invalid Upgrade header");
          return;
        }
        const digest = createHash2("sha1").update(key + GUID).digest("base64");
        if (res.headers["sec-websocket-accept"] !== digest) {
          abortHandshake(websocket, socket, "Invalid Sec-WebSocket-Accept header");
          return;
        }
        const serverProt = res.headers["sec-websocket-protocol"];
        let protError;
        if (serverProt !== void 0) {
          if (!protocolSet.size) {
            protError = "Server sent a subprotocol but none was requested";
          } else if (!protocolSet.has(serverProt)) {
            protError = "Server sent an invalid subprotocol";
          }
        } else if (protocolSet.size) {
          protError = "Server sent no subprotocol";
        }
        if (protError) {
          abortHandshake(websocket, socket, protError);
          return;
        }
        if (serverProt) websocket._protocol = serverProt;
        const secWebSocketExtensions = res.headers["sec-websocket-extensions"];
        if (secWebSocketExtensions !== void 0) {
          if (!perMessageDeflate) {
            const message = "Server sent a Sec-WebSocket-Extensions header but no extension was requested";
            abortHandshake(websocket, socket, message);
            return;
          }
          let extensions;
          try {
            extensions = parse(secWebSocketExtensions);
          } catch (err) {
            const message = "Invalid Sec-WebSocket-Extensions header";
            abortHandshake(websocket, socket, message);
            return;
          }
          const extensionNames = Object.keys(extensions);
          if (extensionNames.length !== 1 || extensionNames[0] !== PerMessageDeflate2.extensionName) {
            const message = "Server indicated an extension that was not requested";
            abortHandshake(websocket, socket, message);
            return;
          }
          try {
            perMessageDeflate.accept(extensions[PerMessageDeflate2.extensionName]);
          } catch (err) {
            const message = "Invalid Sec-WebSocket-Extensions header";
            abortHandshake(websocket, socket, message);
            return;
          }
          websocket._extensions[PerMessageDeflate2.extensionName] = perMessageDeflate;
        }
        websocket.setSocket(socket, head, {
          allowSynchronousEvents: opts.allowSynchronousEvents,
          generateMask: opts.generateMask,
          maxBufferedChunks: opts.maxBufferedChunks,
          maxFragments: opts.maxFragments,
          maxPayload: opts.maxPayload,
          skipUTF8Validation: opts.skipUTF8Validation
        });
      });
      if (opts.finishRequest) {
        opts.finishRequest(req, websocket);
      } else {
        req.end();
      }
    }
    function emitErrorAndClose(websocket, err) {
      websocket._readyState = WebSocket2.CLOSING;
      websocket._errorEmitted = true;
      websocket.emit("error", err);
      websocket.emitClose();
    }
    function netConnect(options) {
      options.path = options.socketPath;
      return net2.connect(options);
    }
    function tlsConnect(options) {
      options.path = void 0;
      if (!options.servername && options.servername !== "") {
        options.servername = net2.isIP(options.host) ? "" : options.host;
      }
      return tls.connect(options);
    }
    function abortHandshake(websocket, stream, message) {
      websocket._readyState = WebSocket2.CLOSING;
      const err = new Error(message);
      Error.captureStackTrace(err, abortHandshake);
      if (stream.setHeader) {
        stream[kAborted] = true;
        stream.abort();
        if (stream.socket && !stream.socket.destroyed) {
          stream.socket.destroy();
        }
        process.nextTick(emitErrorAndClose, websocket, err);
      } else {
        stream.destroy(err);
        stream.once("error", websocket.emit.bind(websocket, "error"));
        stream.once("close", websocket.emitClose.bind(websocket));
      }
    }
    function sendAfterClose(websocket, data, cb) {
      if (data) {
        const length = isBlob(data) ? data.size : toBuffer(data).length;
        if (websocket._socket) websocket._sender._bufferedBytes += length;
        else websocket._bufferedAmount += length;
      }
      if (cb) {
        const err = new Error(
          `WebSocket is not open: readyState ${websocket.readyState} (${readyStates[websocket.readyState]})`
        );
        process.nextTick(cb, err);
      }
    }
    function receiverOnConclude(code, reason) {
      const websocket = this[kWebSocket];
      websocket._closeFrameReceived = true;
      websocket._closeMessage = reason;
      websocket._closeCode = code;
      if (websocket._socket[kWebSocket] === void 0) return;
      websocket._socket.removeListener("data", socketOnData);
      process.nextTick(resume, websocket._socket);
      if (code === 1005) websocket.close();
      else websocket.close(code, reason);
    }
    function receiverOnDrain() {
      const websocket = this[kWebSocket];
      if (!websocket.isPaused) websocket._socket.resume();
    }
    function receiverOnError(err) {
      const websocket = this[kWebSocket];
      if (websocket._socket[kWebSocket] !== void 0) {
        websocket._socket.removeListener("data", socketOnData);
        process.nextTick(resume, websocket._socket);
        websocket.close(err[kStatusCode]);
      }
      if (!websocket._errorEmitted) {
        websocket._errorEmitted = true;
        websocket.emit("error", err);
      }
    }
    function receiverOnFinish() {
      this[kWebSocket].emitClose();
    }
    function receiverOnMessage(data, isBinary) {
      this[kWebSocket].emit("message", data, isBinary);
    }
    function receiverOnPing(data) {
      const websocket = this[kWebSocket];
      if (websocket._autoPong) websocket.pong(data, !this._isServer, NOOP);
      websocket.emit("ping", data);
    }
    function receiverOnPong(data) {
      this[kWebSocket].emit("pong", data);
    }
    function resume(stream) {
      stream.resume();
    }
    function senderOnError(err) {
      const websocket = this[kWebSocket];
      if (websocket.readyState === WebSocket2.CLOSED) return;
      if (websocket.readyState === WebSocket2.OPEN) {
        websocket._readyState = WebSocket2.CLOSING;
        setCloseTimer(websocket);
      }
      this._socket.end();
      if (!websocket._errorEmitted) {
        websocket._errorEmitted = true;
        websocket.emit("error", err);
      }
    }
    function setCloseTimer(websocket) {
      websocket._closeTimer = setTimeout(
        websocket._socket.destroy.bind(websocket._socket),
        websocket._closeTimeout
      );
    }
    function socketOnClose() {
      const websocket = this[kWebSocket];
      this.removeListener("close", socketOnClose);
      this.removeListener("data", socketOnData);
      this.removeListener("end", socketOnEnd);
      websocket._readyState = WebSocket2.CLOSING;
      if (!this._readableState.endEmitted && !websocket._closeFrameReceived && !websocket._receiver._writableState.errorEmitted && this._readableState.length !== 0) {
        const chunk = this.read(this._readableState.length);
        websocket._receiver.write(chunk);
      }
      websocket._receiver.end();
      this[kWebSocket] = void 0;
      clearTimeout(websocket._closeTimer);
      if (websocket._receiver._writableState.finished || websocket._receiver._writableState.errorEmitted) {
        websocket.emitClose();
      } else {
        websocket._receiver.on("error", receiverOnFinish);
        websocket._receiver.on("finish", receiverOnFinish);
      }
    }
    function socketOnData(chunk) {
      if (!this[kWebSocket]._receiver.write(chunk)) {
        this.pause();
      }
    }
    function socketOnEnd() {
      const websocket = this[kWebSocket];
      websocket._readyState = WebSocket2.CLOSING;
      websocket._receiver.end();
      this.end();
    }
    function socketOnError() {
      const websocket = this[kWebSocket];
      this.removeListener("error", socketOnError);
      this.on("error", NOOP);
      if (websocket) {
        websocket._readyState = WebSocket2.CLOSING;
        this.destroy();
      }
    }
  }
});

// node_modules/ws/lib/stream.js
var require_stream3 = __commonJS({
  "node_modules/ws/lib/stream.js"(exports2, module2) {
    "use strict";
    var WebSocket2 = require_websocket();
    var { Duplex } = require("stream");
    function emitClose(stream) {
      stream.emit("close");
    }
    function duplexOnEnd() {
      if (!this.destroyed && this._writableState.finished) {
        this.destroy();
      }
    }
    function duplexOnError(err) {
      this.removeListener("error", duplexOnError);
      this.destroy();
      if (this.listenerCount("error") === 0) {
        this.emit("error", err);
      }
    }
    function createWebSocketStream2(ws, options) {
      let terminateOnDestroy = true;
      const duplex = new Duplex({
        ...options,
        autoDestroy: false,
        emitClose: false,
        objectMode: false,
        writableObjectMode: false
      });
      ws.on("message", function message(msg, isBinary) {
        const data = !isBinary && duplex._readableState.objectMode ? msg.toString() : msg;
        if (!duplex.push(data)) ws.pause();
      });
      ws.once("error", function error(err) {
        if (duplex.destroyed) return;
        terminateOnDestroy = false;
        duplex.destroy(err);
      });
      ws.once("close", function close() {
        if (duplex.destroyed) return;
        duplex.push(null);
      });
      duplex._destroy = function(err, callback) {
        if (ws.readyState === ws.CLOSED) {
          callback(err);
          process.nextTick(emitClose, duplex);
          return;
        }
        let called = false;
        ws.once("error", function error(err2) {
          called = true;
          callback(err2);
        });
        ws.once("close", function close() {
          if (!called) callback(err);
          process.nextTick(emitClose, duplex);
        });
        if (terminateOnDestroy) ws.terminate();
      };
      duplex._final = function(callback) {
        if (ws.readyState === ws.CONNECTING) {
          ws.once("open", function open() {
            duplex._final(callback);
          });
          return;
        }
        if (ws._socket === null) return;
        if (ws._socket._writableState.finished) {
          callback();
          if (duplex._readableState.endEmitted) duplex.destroy();
        } else {
          ws._socket.once("finish", function finish() {
            callback();
          });
          ws.close();
        }
      };
      duplex._read = function() {
        if (ws.isPaused) ws.resume();
      };
      duplex._write = function(chunk, encoding, callback) {
        if (ws.readyState === ws.CONNECTING) {
          ws.once("open", function open() {
            duplex._write(chunk, encoding, callback);
          });
          return;
        }
        ws.send(chunk, callback);
      };
      duplex.on("end", duplexOnEnd);
      duplex.on("error", duplexOnError);
      return duplex;
    }
    module2.exports = createWebSocketStream2;
  }
});

// node_modules/ws/lib/subprotocol.js
var require_subprotocol = __commonJS({
  "node_modules/ws/lib/subprotocol.js"(exports2, module2) {
    "use strict";
    var { tokenChars } = require_validation();
    function parse(header) {
      const protocols = /* @__PURE__ */ new Set();
      let start = -1;
      let end = -1;
      let i = 0;
      for (i; i < header.length; i++) {
        const code = header.charCodeAt(i);
        if (end === -1 && tokenChars[code] === 1) {
          if (start === -1) start = i;
        } else if (i !== 0 && (code === 32 || code === 9)) {
          if (end === -1 && start !== -1) end = i;
        } else if (code === 44) {
          if (start === -1) {
            throw new SyntaxError(`Unexpected character at index ${i}`);
          }
          if (end === -1) end = i;
          const protocol2 = header.slice(start, end);
          if (protocols.has(protocol2)) {
            throw new SyntaxError(`The "${protocol2}" subprotocol is duplicated`);
          }
          protocols.add(protocol2);
          start = end = -1;
        } else {
          throw new SyntaxError(`Unexpected character at index ${i}`);
        }
      }
      if (start === -1 || end !== -1) {
        throw new SyntaxError("Unexpected end of input");
      }
      const protocol = header.slice(start, i);
      if (protocols.has(protocol)) {
        throw new SyntaxError(`The "${protocol}" subprotocol is duplicated`);
      }
      protocols.add(protocol);
      return protocols;
    }
    module2.exports = { parse };
  }
});

// node_modules/ws/lib/websocket-server.js
var require_websocket_server = __commonJS({
  "node_modules/ws/lib/websocket-server.js"(exports2, module2) {
    "use strict";
    var EventEmitter = require("events");
    var http = require("http");
    var { Duplex } = require("stream");
    var { createHash: createHash2 } = require("crypto");
    var extension2 = require_extension();
    var PerMessageDeflate2 = require_permessage_deflate();
    var subprotocol2 = require_subprotocol();
    var WebSocket2 = require_websocket();
    var { CLOSE_TIMEOUT, GUID, kWebSocket } = require_constants();
    var keyRegex = /^[+/0-9A-Za-z]{22}==$/;
    var RUNNING = 0;
    var CLOSING = 1;
    var CLOSED = 2;
    var WebSocketServer2 = class extends EventEmitter {
      /**
       * Create a `WebSocketServer` instance.
       *
       * @param {Object} options Configuration options
       * @param {Boolean} [options.allowSynchronousEvents=true] Specifies whether
       *     any of the `'message'`, `'ping'`, and `'pong'` events can be emitted
       *     multiple times in the same tick
       * @param {Boolean} [options.autoPong=true] Specifies whether or not to
       *     automatically send a pong in response to a ping
       * @param {Number} [options.backlog=511] The maximum length of the queue of
       *     pending connections
       * @param {Boolean} [options.clientTracking=true] Specifies whether or not to
       *     track clients
       * @param {Number} [options.closeTimeout=30000] Duration in milliseconds to
       *     wait for the closing handshake to finish after `websocket.close()` is
       *     called
       * @param {Function} [options.handleProtocols] A hook to handle protocols
       * @param {String} [options.host] The hostname where to bind the server
       * @param {Number} [options.maxBufferedChunks=262144] The maximum number of
       *     buffered data chunks
       * @param {Number} [options.maxFragments=16384] The maximum number of message
       *     fragments
       * @param {Number} [options.maxPayload=104857600] The maximum allowed message
       *     size
       * @param {Boolean} [options.noServer=false] Enable no server mode
       * @param {String} [options.path] Accept only connections matching this path
       * @param {(Boolean|Object)} [options.perMessageDeflate=false] Enable/disable
       *     permessage-deflate
       * @param {Number} [options.port] The port where to bind the server
       * @param {(http.Server|https.Server)} [options.server] A pre-created HTTP/S
       *     server to use
       * @param {Boolean} [options.skipUTF8Validation=false] Specifies whether or
       *     not to skip UTF-8 validation for text and close messages
       * @param {Function} [options.verifyClient] A hook to reject connections
       * @param {Function} [options.WebSocket=WebSocket] Specifies the `WebSocket`
       *     class to use. It must be the `WebSocket` class or class that extends it
       * @param {Function} [callback] A listener for the `listening` event
       */
      constructor(options, callback) {
        super();
        options = {
          allowSynchronousEvents: true,
          autoPong: true,
          maxBufferedChunks: 256 * 1024,
          maxFragments: 16 * 1024,
          maxPayload: 100 * 1024 * 1024,
          skipUTF8Validation: false,
          perMessageDeflate: false,
          handleProtocols: null,
          clientTracking: true,
          closeTimeout: CLOSE_TIMEOUT,
          verifyClient: null,
          noServer: false,
          backlog: null,
          // use default (511 as implemented in net.js)
          server: null,
          host: null,
          path: null,
          port: null,
          WebSocket: WebSocket2,
          ...options
        };
        if (options.port == null && !options.server && !options.noServer || options.port != null && (options.server || options.noServer) || options.server && options.noServer) {
          throw new TypeError(
            'One and only one of the "port", "server", or "noServer" options must be specified'
          );
        }
        if (options.port != null) {
          this._server = http.createServer((req, res) => {
            const body = http.STATUS_CODES[426];
            res.writeHead(426, {
              "Content-Length": body.length,
              "Content-Type": "text/plain"
            });
            res.end(body);
          });
          this._server.listen(
            options.port,
            options.host,
            options.backlog,
            callback
          );
        } else if (options.server) {
          this._server = options.server;
        }
        if (this._server) {
          const emitConnection = this.emit.bind(this, "connection");
          this._removeListeners = addListeners(this._server, {
            listening: this.emit.bind(this, "listening"),
            error: this.emit.bind(this, "error"),
            upgrade: (req, socket, head) => {
              this.handleUpgrade(req, socket, head, emitConnection);
            }
          });
        }
        if (options.perMessageDeflate === true) options.perMessageDeflate = {};
        if (options.clientTracking) {
          this.clients = /* @__PURE__ */ new Set();
          this._shouldEmitClose = false;
        }
        this.options = options;
        this._state = RUNNING;
      }
      /**
       * Returns the bound address, the address family name, and port of the server
       * as reported by the operating system if listening on an IP socket.
       * If the server is listening on a pipe or UNIX domain socket, the name is
       * returned as a string.
       *
       * @return {(Object|String|null)} The address of the server
       * @public
       */
      address() {
        if (this.options.noServer) {
          throw new Error('The server is operating in "noServer" mode');
        }
        if (!this._server) return null;
        return this._server.address();
      }
      /**
       * Stop the server from accepting new connections and emit the `'close'` event
       * when all existing connections are closed.
       *
       * @param {Function} [cb] A one-time listener for the `'close'` event
       * @public
       */
      close(cb) {
        if (this._state === CLOSED) {
          if (cb) {
            this.once("close", () => {
              cb(new Error("The server is not running"));
            });
          }
          process.nextTick(emitClose, this);
          return;
        }
        if (cb) this.once("close", cb);
        if (this._state === CLOSING) return;
        this._state = CLOSING;
        if (this.options.noServer || this.options.server) {
          if (this._server) {
            this._removeListeners();
            this._removeListeners = this._server = null;
          }
          if (this.clients) {
            if (!this.clients.size) {
              process.nextTick(emitClose, this);
            } else {
              this._shouldEmitClose = true;
            }
          } else {
            process.nextTick(emitClose, this);
          }
        } else {
          const server = this._server;
          this._removeListeners();
          this._removeListeners = this._server = null;
          server.close(() => {
            emitClose(this);
          });
        }
      }
      /**
       * See if a given request should be handled by this server instance.
       *
       * @param {http.IncomingMessage} req Request object to inspect
       * @return {Boolean} `true` if the request is valid, else `false`
       * @public
       */
      shouldHandle(req) {
        if (this.options.path) {
          const index = req.url.indexOf("?");
          const pathname = index !== -1 ? req.url.slice(0, index) : req.url;
          if (pathname !== this.options.path) return false;
        }
        return true;
      }
      /**
       * Handle a HTTP Upgrade request.
       *
       * @param {http.IncomingMessage} req The request object
       * @param {Duplex} socket The network socket between the server and client
       * @param {Buffer} head The first packet of the upgraded stream
       * @param {Function} cb Callback
       * @public
       */
      handleUpgrade(req, socket, head, cb) {
        socket.on("error", socketOnError);
        const key = req.headers["sec-websocket-key"];
        const upgrade = req.headers.upgrade;
        const version = +req.headers["sec-websocket-version"];
        if (req.method !== "GET") {
          const message = "Invalid HTTP method";
          abortHandshakeOrEmitwsClientError(this, req, socket, 405, message);
          return;
        }
        if (upgrade === void 0 || upgrade.toLowerCase() !== "websocket") {
          const message = "Invalid Upgrade header";
          abortHandshakeOrEmitwsClientError(this, req, socket, 400, message);
          return;
        }
        if (key === void 0 || !keyRegex.test(key)) {
          const message = "Missing or invalid Sec-WebSocket-Key header";
          abortHandshakeOrEmitwsClientError(this, req, socket, 400, message);
          return;
        }
        if (version !== 13 && version !== 8) {
          const message = "Missing or invalid Sec-WebSocket-Version header";
          abortHandshakeOrEmitwsClientError(this, req, socket, 400, message, {
            "Sec-WebSocket-Version": "13, 8"
          });
          return;
        }
        if (!this.shouldHandle(req)) {
          abortHandshake(socket, 400);
          return;
        }
        const secWebSocketProtocol = req.headers["sec-websocket-protocol"];
        let protocols = /* @__PURE__ */ new Set();
        if (secWebSocketProtocol !== void 0) {
          try {
            protocols = subprotocol2.parse(secWebSocketProtocol);
          } catch (err) {
            const message = "Invalid Sec-WebSocket-Protocol header";
            abortHandshakeOrEmitwsClientError(this, req, socket, 400, message);
            return;
          }
        }
        const secWebSocketExtensions = req.headers["sec-websocket-extensions"];
        const extensions = {};
        if (this.options.perMessageDeflate && secWebSocketExtensions !== void 0) {
          const perMessageDeflate = new PerMessageDeflate2({
            ...this.options.perMessageDeflate,
            isServer: true,
            maxPayload: this.options.maxPayload
          });
          try {
            const offers = extension2.parse(secWebSocketExtensions);
            if (offers[PerMessageDeflate2.extensionName]) {
              perMessageDeflate.accept(offers[PerMessageDeflate2.extensionName]);
              extensions[PerMessageDeflate2.extensionName] = perMessageDeflate;
            }
          } catch (err) {
            const message = "Invalid or unacceptable Sec-WebSocket-Extensions header";
            abortHandshakeOrEmitwsClientError(this, req, socket, 400, message);
            return;
          }
        }
        if (this.options.verifyClient) {
          const info = {
            origin: req.headers[`${version === 8 ? "sec-websocket-origin" : "origin"}`],
            secure: !!(req.socket.authorized || req.socket.encrypted),
            req
          };
          if (this.options.verifyClient.length === 2) {
            this.options.verifyClient(info, (verified, code, message, headers) => {
              if (!verified) {
                return abortHandshake(socket, code || 401, message, headers);
              }
              this.completeUpgrade(
                extensions,
                key,
                protocols,
                req,
                socket,
                head,
                cb
              );
            });
            return;
          }
          if (!this.options.verifyClient(info)) return abortHandshake(socket, 401);
        }
        this.completeUpgrade(extensions, key, protocols, req, socket, head, cb);
      }
      /**
       * Upgrade the connection to WebSocket.
       *
       * @param {Object} extensions The accepted extensions
       * @param {String} key The value of the `Sec-WebSocket-Key` header
       * @param {Set} protocols The subprotocols
       * @param {http.IncomingMessage} req The request object
       * @param {Duplex} socket The network socket between the server and client
       * @param {Buffer} head The first packet of the upgraded stream
       * @param {Function} cb Callback
       * @throws {Error} If called more than once with the same socket
       * @private
       */
      completeUpgrade(extensions, key, protocols, req, socket, head, cb) {
        if (!socket.readable || !socket.writable) return socket.destroy();
        if (socket[kWebSocket]) {
          throw new Error(
            "server.handleUpgrade() was called more than once with the same socket, possibly due to a misconfiguration"
          );
        }
        if (this._state > RUNNING) return abortHandshake(socket, 503);
        const digest = createHash2("sha1").update(key + GUID).digest("base64");
        const headers = [
          "HTTP/1.1 101 Switching Protocols",
          "Upgrade: websocket",
          "Connection: Upgrade",
          `Sec-WebSocket-Accept: ${digest}`
        ];
        const ws = new this.options.WebSocket(null, void 0, this.options);
        if (protocols.size) {
          const protocol = this.options.handleProtocols ? this.options.handleProtocols(protocols, req) : protocols.values().next().value;
          if (protocol) {
            headers.push(`Sec-WebSocket-Protocol: ${protocol}`);
            ws._protocol = protocol;
          }
        }
        if (extensions[PerMessageDeflate2.extensionName]) {
          const params = extensions[PerMessageDeflate2.extensionName].params;
          const value = extension2.format({
            [PerMessageDeflate2.extensionName]: [params]
          });
          headers.push(`Sec-WebSocket-Extensions: ${value}`);
          ws._extensions = extensions;
        }
        this.emit("headers", headers, req);
        socket.write(headers.concat("\r\n").join("\r\n"));
        socket.removeListener("error", socketOnError);
        ws.setSocket(socket, head, {
          allowSynchronousEvents: this.options.allowSynchronousEvents,
          maxBufferedChunks: this.options.maxBufferedChunks,
          maxFragments: this.options.maxFragments,
          maxPayload: this.options.maxPayload,
          skipUTF8Validation: this.options.skipUTF8Validation
        });
        if (this.clients) {
          this.clients.add(ws);
          ws.on("close", () => {
            this.clients.delete(ws);
            if (this._shouldEmitClose && !this.clients.size) {
              process.nextTick(emitClose, this);
            }
          });
        }
        cb(ws, req);
      }
    };
    module2.exports = WebSocketServer2;
    function addListeners(server, map) {
      for (const event of Object.keys(map)) server.on(event, map[event]);
      return function removeListeners() {
        for (const event of Object.keys(map)) {
          server.removeListener(event, map[event]);
        }
      };
    }
    function emitClose(server) {
      server._state = CLOSED;
      server.emit("close");
    }
    function socketOnError() {
      this.destroy();
    }
    function abortHandshake(socket, code, message, headers) {
      message = message || http.STATUS_CODES[code];
      headers = {
        Connection: "close",
        "Content-Type": "text/html",
        "Content-Length": Buffer.byteLength(message),
        ...headers
      };
      socket.once("finish", socket.destroy);
      socket.end(
        `HTTP/1.1 ${code} ${http.STATUS_CODES[code]}\r
` + Object.keys(headers).map((h) => `${h}: ${headers[h]}`).join("\r\n") + "\r\n\r\n" + message
      );
    }
    function abortHandshakeOrEmitwsClientError(server, req, socket, code, message, headers) {
      if (server.listenerCount("wsClientError")) {
        const err = new Error(message);
        Error.captureStackTrace(err, abortHandshakeOrEmitwsClientError);
        server.emit("wsClientError", err, socket, req);
      } else {
        abortHandshake(socket, code, message, headers);
      }
    }
  }
});

// node_modules/minimist/index.js
var require_minimist = __commonJS({
  "node_modules/minimist/index.js"(exports2, module2) {
    "use strict";
    function hasKey(obj, keys) {
      var o = obj;
      keys.slice(0, -1).forEach(function(key2) {
        o = o[key2] || {};
      });
      var key = keys[keys.length - 1];
      return key in o;
    }
    function isNumber(x) {
      if (typeof x === "number") {
        return true;
      }
      if (/^0x[0-9a-f]+$/i.test(x)) {
        return true;
      }
      return /^[-+]?(?:\d+(?:\.\d*)?|\.\d+)(e[-+]?\d+)?$/.test(x);
    }
    function isConstructorOrProto(obj, key) {
      return key === "constructor" && typeof obj[key] === "function" || key === "__proto__";
    }
    module2.exports = function(args, opts) {
      if (!opts) {
        opts = {};
      }
      var flags = {
        bools: {},
        strings: {},
        unknownFn: null
      };
      if (typeof opts.unknown === "function") {
        flags.unknownFn = opts.unknown;
      }
      if (typeof opts.boolean === "boolean" && opts.boolean) {
        flags.allBools = true;
      } else {
        [].concat(opts.boolean).filter(Boolean).forEach(function(key2) {
          flags.bools[key2] = true;
        });
      }
      var aliases = {};
      function aliasIsBoolean(key2) {
        return aliases[key2].some(function(x) {
          return flags.bools[x];
        });
      }
      Object.keys(opts.alias || {}).forEach(function(key2) {
        aliases[key2] = [].concat(opts.alias[key2]);
        aliases[key2].forEach(function(x) {
          aliases[x] = [key2].concat(aliases[key2].filter(function(y) {
            return x !== y;
          }));
        });
      });
      [].concat(opts.string).filter(Boolean).forEach(function(key2) {
        flags.strings[key2] = true;
        if (aliases[key2]) {
          [].concat(aliases[key2]).forEach(function(k) {
            flags.strings[k] = true;
          });
        }
      });
      var defaults = opts.default || {};
      var argv = { _: [] };
      function argDefined(key2, arg2) {
        return flags.allBools && /^--[^=]+$/.test(arg2) || flags.strings[key2] || flags.bools[key2] || aliases[key2];
      }
      function setKey(obj, keys, value2) {
        var o = obj;
        for (var i2 = 0; i2 < keys.length - 1; i2++) {
          var key2 = keys[i2];
          if (isConstructorOrProto(o, key2)) {
            return;
          }
          if (o[key2] === void 0) {
            o[key2] = {};
          }
          if (o[key2] === Object.prototype || o[key2] === Number.prototype || o[key2] === String.prototype) {
            o[key2] = {};
          }
          if (o[key2] === Array.prototype) {
            o[key2] = [];
          }
          o = o[key2];
        }
        var lastKey = keys[keys.length - 1];
        if (isConstructorOrProto(o, lastKey)) {
          return;
        }
        if (o === Object.prototype || o === Number.prototype || o === String.prototype) {
          o = {};
        }
        if (o === Array.prototype) {
          o = [];
        }
        if (o[lastKey] === void 0 || flags.bools[lastKey] || typeof o[lastKey] === "boolean") {
          o[lastKey] = value2;
        } else if (Array.isArray(o[lastKey])) {
          o[lastKey].push(value2);
        } else {
          o[lastKey] = [o[lastKey], value2];
        }
      }
      function setArg(key2, val, arg2) {
        if (arg2 && flags.unknownFn && !argDefined(key2, arg2)) {
          if (flags.unknownFn(arg2) === false) {
            return;
          }
        }
        var value2 = !flags.strings[key2] && isNumber(val) ? Number(val) : val;
        setKey(argv, key2.split("."), value2);
        (aliases[key2] || []).forEach(function(x) {
          setKey(argv, x.split("."), value2);
        });
      }
      Object.keys(flags.bools).forEach(function(key2) {
        setArg(key2, defaults[key2] === void 0 ? false : defaults[key2]);
      });
      var notFlags = [];
      if (args.indexOf("--") !== -1) {
        notFlags = args.slice(args.indexOf("--") + 1);
        args = args.slice(0, args.indexOf("--"));
      }
      for (var i = 0; i < args.length; i++) {
        var arg = args[i];
        var key;
        var next;
        if (/^--.+=/.test(arg)) {
          var m = arg.match(/^--([^=]+)=([\s\S]*)$/);
          key = m[1];
          var value = m[2];
          if (flags.bools[key]) {
            value = value !== "false";
          }
          setArg(key, value, arg);
        } else if (/^--no-.+/.test(arg)) {
          key = arg.match(/^--no-(.+)/)[1];
          setArg(key, false, arg);
        } else if (/^--.+/.test(arg)) {
          key = arg.match(/^--(.+)/)[1];
          next = args[i + 1];
          if (next !== void 0 && !/^(-|--)[^-]/.test(next) && !flags.bools[key] && !flags.allBools && (aliases[key] ? !aliasIsBoolean(key) : true)) {
            setArg(key, next, arg);
            i += 1;
          } else if (/^(true|false)$/.test(next)) {
            setArg(key, next === "true", arg);
            i += 1;
          } else {
            setArg(key, flags.strings[key] ? "" : true, arg);
          }
        } else if (/^-[^-]+/.test(arg)) {
          var letters = arg.slice(1, -1).split("");
          var broken = false;
          for (var j = 0; j < letters.length; j++) {
            next = arg.slice(j + 2);
            if (next === "-") {
              setArg(letters[j], next, arg);
              continue;
            }
            if (/[A-Za-z]/.test(letters[j]) && next[0] === "=") {
              setArg(letters[j], next.slice(1), arg);
              broken = true;
              break;
            }
            if (/[A-Za-z]/.test(letters[j]) && /-?\d+(\.\d*)?(e-?\d+)?$/.test(next)) {
              setArg(letters[j], next, arg);
              broken = true;
              break;
            }
            if (letters[j + 1] && letters[j + 1].match(/\W/)) {
              setArg(letters[j], arg.slice(j + 2), arg);
              broken = true;
              break;
            } else {
              setArg(letters[j], flags.strings[letters[j]] ? "" : true, arg);
            }
          }
          key = arg.slice(-1)[0];
          if (!broken && key !== "-") {
            if (args[i + 1] && !/^(-|--)[^-]/.test(args[i + 1]) && !flags.bools[key] && (aliases[key] ? !aliasIsBoolean(key) : true)) {
              setArg(key, args[i + 1], arg);
              i += 1;
            } else if (args[i + 1] && /^(true|false)$/.test(args[i + 1])) {
              setArg(key, args[i + 1] === "true", arg);
              i += 1;
            } else {
              setArg(key, flags.strings[key] ? "" : true, arg);
            }
          }
        } else {
          if (!flags.unknownFn || flags.unknownFn(arg) !== false) {
            argv._.push(flags.strings._ || !isNumber(arg) ? arg : Number(arg));
          }
          if (opts.stopEarly) {
            argv._.push.apply(argv._, args.slice(i + 1));
            break;
          }
        }
      }
      Object.keys(defaults).forEach(function(k) {
        if (!hasKey(argv, k.split("."))) {
          setKey(argv, k.split("."), defaults[k]);
          (aliases[k] || []).forEach(function(x) {
            setKey(argv, x.split("."), defaults[k]);
          });
        }
      });
      if (opts["--"]) {
        argv["--"] = notFlags.slice();
      } else {
        notFlags.forEach(function(k) {
          argv._.push(k);
        });
      }
      return argv;
    };
  }
});

// node_modules/@eniac/flexdesigner/dist/logger.js
var import_winston = __toESM(require_winston());
var import_winston_daily_rotate_file = __toESM(require_winston_daily_rotate_file());
var import_fs = __toESM(require("fs"));
var cachedLogger = null;
var logDir = require("node:path").join((() => {
  const v = process.argv.find((x) => x.startsWith("--dir="));
  const i = process.argv.indexOf("--dir");
  return v ? v.slice(6) : i >= 0 ? process.argv[i + 1] : require("node:path").resolve(__dirname, "..");
})(), "logs");
if (!import_fs.default.existsSync(logDir)) {
  import_fs.default.mkdirSync(logDir, { recursive: true });
}
import_winston.default.addColors({
  info: "bold cyan",
  warn: "yellowBG bold white",
  error: "redBG bold white",
  debug: "green"
});
function safeStringify(obj, space = 2) {
  const seen = /* @__PURE__ */ new WeakSet();
  return JSON.stringify(obj, function(key, value) {
    if (typeof value === "object" && value !== null) {
      if (seen.has(value)) {
        return "[Circular]";
      }
      seen.add(value);
    }
    return value;
  }, space);
}
function isTypedArray(value) {
  return value instanceof Int8Array || value instanceof Uint8Array || value instanceof Uint8ClampedArray || value instanceof Int16Array || value instanceof Uint16Array || value instanceof Int32Array || value instanceof Uint32Array || value instanceof Float32Array || value instanceof Float64Array || typeof BigInt64Array !== "undefined" && value instanceof BigInt64Array || typeof BigUint64Array !== "undefined" && value instanceof BigUint64Array;
}
function formatValue(value) {
  if (value === null)
    return "null";
  if (value === void 0)
    return "undefined";
  if (value instanceof Error) {
    return `${value.name}: ${value.message}
${value.stack}`;
  }
  if (isTypedArray(value)) {
    const hexStr = Array.from(value).map((b) => `0x${b.toString(16).padStart(2, "0")}`).join(", ");
    return `${value.constructor.name} [ ${hexStr} ]`;
  }
  if (value instanceof ArrayBuffer) {
    const typedArray = new Uint8Array(value);
    const hexStr = Array.from(typedArray).map((b) => `0x${b.toString(16).padStart(2, "0")}`).join(", ");
    return `ArrayBuffer(${value.byteLength}) [ ${hexStr} ]`;
  }
  if (value instanceof Date) {
    return `Date(${value.toISOString()})`;
  }
  if (value instanceof Map) {
    const entries = [];
    for (const [k, v] of value.entries()) {
      entries.push(`${formatValue(k)} => ${formatValue(v)}`);
    }
    return `Map(${value.size}) { ${entries.join(", ")} }`;
  }
  if (value instanceof Set) {
    const entries = [];
    for (const v of value.values()) {
      entries.push(formatValue(v));
    }
    return `Set(${value.size}) { ${entries.join(", ")} }`;
  }
  if (Array.isArray(value)) {
    return safeStringify(value);
  }
  if (typeof value === "function") {
    return `Function(${value.name || "anonymous"})`;
  }
  if (typeof value === "symbol") {
    return value.toString();
  }
  if (typeof value === "bigint") {
    return `BigInt(${value.toString()})`;
  }
  if (typeof value === "number" || typeof value === "boolean" || typeof value === "string") {
    return String(value);
  }
  if (typeof value === "object") {
    return safeStringify(value);
  }
  return String(value);
}
function formatMessage(args) {
  return args.map(formatValue).join(" ");
}
function createMainLogger() {
  const mainLogger = import_winston.default.createLogger({
    level: "debug",
    format: import_winston.default.format.combine(import_winston.default.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss.SSS" }), import_winston.default.format.printf(({ message, timestamp, level, scope }) => {
      const scopeStr = scope ? `[${scope}]` : "";
      return `${timestamp} [${level}]${scopeStr} -> ${message}`;
    })),
    transports: [
      new import_winston_daily_rotate_file.default({
        filename: "%DATE%.log",
        dirname: logDir,
        datePattern: "YYYY-MM-DD",
        zippedArchive: true,
        maxSize: "20m",
        maxFiles: "14d"
      })
    ]
  });
  mainLogger.add(new import_winston.default.transports.Console({
    format: import_winston.default.format.combine(import_winston.default.format.colorize({ all: true }), import_winston.default.format.printf(({ message, timestamp, level, scope }) => {
      const scopeStr = scope ? `(${scope})` : "";
      return `${timestamp} [${level}]${scopeStr} -> ${message}`;
    }))
  }));
  ["info", "warn", "error", "debug"].forEach((lvl) => {
    const original = mainLogger[lvl];
    mainLogger[lvl] = function(...args) {
      const msg = formatMessage(args);
      return original.call(this, msg);
    };
  });
  return mainLogger;
}
if (!cachedLogger) {
  cachedLogger = createMainLogger();
}
var logger_default = cachedLogger;

// node_modules/ws/wrapper.mjs
var import_stream = __toESM(require_stream3(), 1);
var import_extension = __toESM(require_extension(), 1);
var import_permessage_deflate = __toESM(require_permessage_deflate(), 1);
var import_receiver = __toESM(require_receiver(), 1);
var import_sender = __toESM(require_sender(), 1);
var import_subprotocol = __toESM(require_subprotocol(), 1);
var import_websocket = __toESM(require_websocket(), 1);
var import_websocket_server = __toESM(require_websocket_server(), 1);
var wrapper_default = import_websocket.default;

// node_modules/uuid/dist/esm/stringify.js
var byteToHex = [];
for (let i = 0; i < 256; ++i) {
  byteToHex.push((i + 256).toString(16).slice(1));
}
function unsafeStringify(arr, offset = 0) {
  return (byteToHex[arr[offset + 0]] + byteToHex[arr[offset + 1]] + byteToHex[arr[offset + 2]] + byteToHex[arr[offset + 3]] + "-" + byteToHex[arr[offset + 4]] + byteToHex[arr[offset + 5]] + "-" + byteToHex[arr[offset + 6]] + byteToHex[arr[offset + 7]] + "-" + byteToHex[arr[offset + 8]] + byteToHex[arr[offset + 9]] + "-" + byteToHex[arr[offset + 10]] + byteToHex[arr[offset + 11]] + byteToHex[arr[offset + 12]] + byteToHex[arr[offset + 13]] + byteToHex[arr[offset + 14]] + byteToHex[arr[offset + 15]]).toLowerCase();
}

// node_modules/uuid/dist/esm/rng.js
var import_crypto = require("crypto");
var rnds8Pool = new Uint8Array(256);
var poolPtr = rnds8Pool.length;
function rng() {
  if (poolPtr > rnds8Pool.length - 16) {
    (0, import_crypto.randomFillSync)(rnds8Pool);
    poolPtr = 0;
  }
  return rnds8Pool.slice(poolPtr, poolPtr += 16);
}

// node_modules/uuid/dist/esm/native.js
var import_crypto2 = require("crypto");
var native_default = { randomUUID: import_crypto2.randomUUID };

// node_modules/uuid/dist/esm/v4.js
function v4(options, buf, offset) {
  if (native_default.randomUUID && !buf && !options) {
    return native_default.randomUUID();
  }
  options = options || {};
  const rnds = options.random ?? options.rng?.() ?? rng();
  if (rnds.length < 16) {
    throw new Error("Random bytes length must be >= 16");
  }
  rnds[6] = rnds[6] & 15 | 64;
  rnds[8] = rnds[8] & 63 | 128;
  if (buf) {
    offset = offset || 0;
    if (offset < 0 || offset + 16 > buf.length) {
      throw new RangeError(`UUID byte range ${offset}:${offset + 15} is out of buffer bounds`);
    }
    for (let i = 0; i < 16; ++i) {
      buf[offset + i] = rnds[i];
    }
    return buf;
  }
  return unsafeStringify(rnds);
}
var v4_default = v4;

// node_modules/@eniac/flexdesigner/dist/transport.js
var __awaiter = function(thisArg, _arguments, P, generator) {
  function adopt(value) {
    return value instanceof P ? value : new P(function(resolve) {
      resolve(value);
    });
  }
  return new (P || (P = Promise))(function(resolve, reject) {
    function fulfilled(value) {
      try {
        step(generator.next(value));
      } catch (e) {
        reject(e);
      }
    }
    function rejected(value) {
      try {
        step(generator["throw"](value));
      } catch (e) {
        reject(e);
      }
    }
    function step(result) {
      result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected);
    }
    step((generator = generator.apply(thisArg, _arguments || [])).next());
  });
};
var logger = logger_default.child({ scope: "plugin" });
var PluginTransport = class {
  /**
   * @brief Constructor for the Plugin class.
   */
  constructor(uuid, port) {
    this.uuid = uuid;
    this.port = port;
    this.ws = null;
    this.handlers = {};
    this.pendingCalls = {};
  }
  /**
   * @brief Starts the WebSocket connection by extracting port and uid from command-line arguments.
   *
   * Detailed description:
   * The method parses the command-line arguments for `port`, `uid`, and `dir` options,
   * and uses them to establish a WebSocket connection with the server. It sends an
   * initial "startup" command once connected.
   *
   * @throws {Error} If port, uid, or dir are not provided in the command-line arguments.
   */
  start() {
    logger.info(`Starting plugin transport with port ${this.port}, uid ${this.uuid}`);
    const serverUrl = `ws://localhost:${this.port}`;
    this.ws = new wrapper_default(serverUrl);
    this.ws.on("open", () => {
      logger.info(`Connected to server at ${serverUrl}, Sending init command`);
      this._send("startup", { pluginID: this.uuid });
    });
    this.ws.on("message", (msg) => {
      this._handleMessage(msg).catch((err) => {
        logger.error(`Error handling message: ${err.message}`);
      });
    });
    this.ws.on("close", () => {
      logger.warn("Connection closed");
      logger.info("Retrying connection in 5 seconds...");
      setTimeout(this.start, 5e3);
    });
    this.ws.on("error", (err) => {
      logger.error(`WebSocket error: ${err.message}`);
      logger.info("Retrying connection in 5 seconds...");
      setTimeout(this.start, 5e3);
    });
  }
  _send(command, payload) {
    const msg_uuid = v4_default();
    const cmd = {
      pluginID: this.uuid,
      type: command,
      payload,
      timestamp: Date.now(),
      uuid: msg_uuid
    };
    this.ws.send(JSON.stringify(cmd));
    return msg_uuid;
  }
  _sendResponse(uuid, result, status = "success") {
    const cmd = {
      pluginID: this.uuid,
      type: "response",
      payload: result,
      timestamp: Date.now(),
      uuid,
      status
    };
    this.ws.send(JSON.stringify(cmd));
  }
  /**
   * @brief Sends a request to the server with a specific command and payload.
   *
   * Detailed description:
   * The method creates a `PluginCommand` and sends it via WebSocket.
   * It also sets a timeout to reject the request if no response is received.
   *
   * @param {string} command - The command to send to the server.
   * @param {Object} payload - The payload to send along with the command.
   * @param {number} timeout - The timeout in milliseconds before rejecting the request. Default is 5000 ms.
   * @returns {Promise<any>} A promise that resolves with the response payload or rejects with an error.
   */
  call(command, payload, timeout = 5e3) {
    return new Promise((resolve, reject) => {
      const uuid = this._send(command, payload);
      let timer = null;
      if (timeout > 0) {
        timer = setTimeout(() => {
          delete this.pendingCalls[uuid];
          reject(new Error(`Request timed out, command: ${command}, payload: ${JSON.stringify(payload)}`));
        }, timeout);
      }
      this.pendingCalls[uuid] = { resolve, reject, timer };
    });
  }
  /**
   * @brief Handles incoming WebSocket messages.
   *
   * Detailed description:
   * The method processes messages from the server, checking if they are
   * responses to previous requests, or if they are broadcasts that need to be handled
   * by registered message handlers.
   *
   * @param {string} msg - The received message in string format.
   * @returns {void}
   */
  _handleMessage(msg) {
    return __awaiter(this, void 0, void 0, function* () {
      let cmd;
      try {
        cmd = JSON.parse(msg);
      } catch (e) {
        logger.error(`Invalid message format: ${msg}`);
        return;
      }
      if (this.pendingCalls[cmd.uuid]) {
        const { resolve, reject, timer } = this.pendingCalls[cmd.uuid];
        if (timer) {
          clearTimeout(timer);
        }
        delete this.pendingCalls[cmd.uuid];
        if (cmd.status === "success")
          resolve(cmd.payload);
        else
          reject(new Error(`Request failed: ${cmd.error || "Unknown error"}, Command: ${cmd.toString()}`));
        return;
      }
      const handler = this.handlers[cmd.type];
      if (handler) {
        const result = yield handler(cmd.payload);
        this._sendResponse(cmd.uuid, result);
      }
    });
  }
  /**
   * @brief Registers a handler for incoming messages of a specific type.
   *
   * Detailed description:
   * This method allows the registration of handlers for specific message types,
   * which are invoked when a message of that type is received from the server.
   *
   * @param {string} type - The message type to handle.
   * @param {Function} handler - The handler function that processes the message payload.
   * @returns {void}
   */
  on(type, handler) {
    this.handlers[type] = handler;
  }
  /**
   * @brief Unregisters a handler for a specific message type.
   *
   * @param {string} type - The message type to unregister the handler for.
   * @returns {void}
   */
  off(type) {
    delete this.handlers[type];
  }
};
var transport_default = PluginTransport;

// node_modules/@eniac/flexdesigner/dist/plugin_client.js
var import_minimist = __toESM(require_minimist());
var logger2 = logger_default.child({ scope: "plugin" });
var uiLogger = logger_default.child({ scope: "UI" });
var DynamicKey = class {
  /**
   * @brief Constructor for the DynamicKey class.
   *
   * @param {PluginTransport} transport - The plugin transport.
   */
  constructor(transport) {
    this.transport = transport;
  }
  /**
   * @brief Clear all dynamic keys for a specific key.
   *
   * Detailed description:
   * This method removes all dynamic keys associated with the specified key,
   * effectively resetting the key to its initial state.
   *
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  clear(serialNumber, key) {
    return this.transport.call("dynamic-plugin", {
      cmd: "clear",
      serialNumber,
      key
    });
  }
  /**
   * @brief Add a new dynamic key at the specified index.
   *
   * Detailed description:
   * This method adds a new dynamic key with the specified background and user data.
   * The key will be inserted at the given index position.
   * The drawing functionality is similar to the plugin.draw method.
   *
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @param {number} addToIndex - The index position where the new key should be added.
   * @param {string} backgroundType - The type of background. Possible values:
   * ```
   * "base64" | "draw"
   * ```
   * When "base64" is selected, it will directly draw the specified image to the key.
   * When "draw" is selected, it will render a background image based on the key object you specify.
   * @param {string} backgroundData - The background data (base64 image string for "base64" type), or the key object for "draw" type.
   * @param {number} width - The width of the dynamic key in pixels, from 60 to 1000.
   * @param {Object} userData - Additional user data to associate with the key. This data will be sent to the plugin when the key is pressed.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  add(serialNumber, key, addToIndex, backgroundType, backgroundData, width, userData) {
    return this.transport.call("dynamic-plugin", {
      cmd: "add",
      serialNumber,
      backgroundType,
      key,
      index: addToIndex,
      width,
      backgroundData,
      userData
    });
  }
  /**
   * @brief Remove a dynamic key at the specified index.
   *
   * Detailed description:
   * This method removes the dynamic key located at the specified index position.
   *
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @param {number} index - The index of the dynamic key to remove.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  remove(serialNumber, key, index) {
    return this.transport.call("dynamic-plugin", {
      cmd: "remove",
      serialNumber,
      key,
      index
    });
  }
  /**
   * @brief Set the width of the parent key container.
   *
   * Detailed description:
   * This method updates the width property of the parent key, affecting how
   * the dynamic keys are displayed within the container.
   *
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @param {number} width - The new width in pixels for the parent key container.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  setWidth(serialNumber, key, width) {
    return this.transport.call("dynamic-plugin", {
      cmd: "set",
      serialNumber,
      key,
      data: {
        width
      }
    });
  }
  /**
   * @brief Move a dynamic key from one position to another.
   *
   * Detailed description:
   * This method moves a dynamic key from the source index to the destination index,
   * reordering the keys within the container.
   *
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @param {number} srcIndex - The current index of the key to move.
   * @param {number} dstIndex - The target index where the key should be moved.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  move(serialNumber, key, srcIndex, dstIndex) {
    return this.transport.call("dynamic-plugin", {
      cmd: "move",
      serialNumber,
      key,
      srcIndex,
      dstIndex
    });
  }
  /**
   * @brief Draw or update the background of a specific dynamic key.
   *
   * Detailed description:
   * This method updates the visual appearance of a dynamic key at the specified index
   * by changing its background image or drawing content.
   *
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @param {number} index - The index of the dynamic key to update.
   * @param {string} backgroundType - The type of background. Possible values:
   * ```
   * "base64" | "draw"
   * ```
   * When "base64" is selected, it will directly draw the specified image to the key.
   * When "draw" is selected, it will render a background image based on the key object you specify.
   * @param {string} backgroundData - The background data (base64 image string for "base64" type). When "base64" is selected, backgroundData should be a base64 image string.
   * @param {number} width - The width of the dynamic key in pixels.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  draw(serialNumber, key, index, backgroundType, backgroundData, width) {
    return this.transport.call("dynamic-plugin", {
      cmd: "draw",
      serialNumber,
      backgroundType,
      key,
      index,
      width,
      backgroundData
    });
  }
  /**
   * @brief Update user data for a specific dynamic key.
   *
   * Detailed description:
   * This method updates the user data associated with a dynamic key at the specified index.
   *
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @param {number} index - The index of the dynamic key to update.
   * @param {Object} userData - The new user data to associate with the key.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  update(serialNumber, key, index, userData) {
    return this.transport.call("dynamic-plugin", {
      cmd: "update",
      serialNumber,
      key,
      index,
      userData
    });
  }
  /**
   * @brief Refresh the dynamic key.
   *
   * Detailed description:
   * This method refreshes the dynamic key. It is recommended to call this method with a 50ms delay after changing the width of a dynamic key to prevent display anomalies.
   *
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  refresh(serialNumber, key) {
    return this.transport.call("dynamic-plugin", {
      cmd: "refresh",
      serialNumber,
      key
    });
  }
};
var Plugin = class {
  /**
   * @brief Constructor for the Plugin class.
   */
  constructor() {
    const argv = (0, import_minimist.default)(process.argv.slice(2));
    this.uuid = argv.uid;
    this.directory = argv.dir;
    this.port = parseInt(argv.port);
    if (!this.uuid || !this.directory || !this.port) {
      console.error(`Usage: node plugin_client.js --port=<port> --uid=<uid> --dir=<dir>, Args: ${JSON.stringify(process.argv.slice(2))}`);
      process.exit(1);
    }
    this.transport = new transport_default(this.uuid, this.port);
    this.dynamickey = new DynamicKey(this.transport);
  }
  /**
   * @brief Starts the WebSocket connection by extracting port and uid from command-line arguments.
   *
   * Detailed description:
   * The method parses the command-line arguments for `port`, `uid`, and `dir` options,
   * and uses them to establish a WebSocket connection with the server. It sends an
   * initial "startup" command once connected.
   *
   * @throws {Error} If port, uid, or dir are not provided in the command-line arguments.
   */
  start() {
    logger2.info(`Starting plugin client with dir ${this.directory}`);
    this.on("ui.log", (payload) => {
      try {
        uiLogger[payload.level](payload.msg);
      } catch (error) {
        logger2.warn(`Invalid log level: ${payload.level}, message: ${payload.msg}`);
      }
    });
    this.transport.start();
  }
  on(type, handler) {
    this.transport.on(type, handler);
  }
  /**
   * @brief Unregisters a handler for a specific message type.
   *
   * @param {string} type - The message type to unregister the handler for.
   * @returns {void}
   */
  off(type) {
    this.transport.off(type);
  }
  draw(serialNumber, key, type = "draw", base64 = null) {
    return this.transport.call("draw", {
      serialNumber,
      type,
      key,
      base64
    });
  }
  /**
   * @brief Draw a background image directly on the device screen. Only supports keys with type DirectDraw
   *
   * Detailed description:
   * This method draws a background image directly on the device screen,
   * replacing the current screen content.
   *
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @param {string} backgroundData - The background data (base64 image string).
   * @param {boolean} diffUpdate - If true, only update changed areas, otherwise always perform full screen update
   * @param {Types.DirectDrawRegion} region - The region to update. If null, the entire screen will be updated. Height is fixed to 60, and y is fixed to 0.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  directDraw(serialNumber, key, backgroundData, diffUpdate = false, offsetX = 0) {
    return this.transport.call("direct-draw", {
      serialNumber,
      key,
      data: backgroundData,
      diffUpdate,
      offsetX
    });
  }
  /**
   * @brief Send chart data for performance monitoring.
   *
   * Detailed description:
   * This method sends an array of performance metrics to be displayed in custom charts.
   * Each chart data object contains information about a specific metric including its
   * current value, unit, and display formatting.
   *
   * @param {Array<Types.ChartDataItem>} chartDataArray - An array of chart data objects. See comments in `ChartDataItem` for details.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  sendChartData(chartDataArray) {
    return this.transport.call("custom-chart-data", {
      data: chartDataArray
    });
  }
  /**
   * @brief Send a control command to the device.
   * @param {string} serialNumber - The serial number of the device.
   * @param {Types.ControlCommand} command - The command to send. One of the following:
   * ```
   * "sys.sleep": Put the device to sleep
   * "sys.wake": Wake up the device
   * "haptic.click": Trigger a click vibration
   * "hapic.click": Same as haptic.click (legacy typo string; kept for backward compatibility)
   * ```
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  sendControlCommand(serialNumber, command) {
    return this.transport.call("control-command", {
      serialNumber,
      command
    });
  }
  /**
   * @brief Show snackbar message on flexbar.
   *
   * Detailed description:
   * This method sends a command to show a snackbar message on flexbar with specified level and icon.
   * The message and level are required parameters, while other parameters are optional.
   *
   * @param {string} serialNumber - The serial number of the device.
   * @param {string} msg - The message content to display (required).
   * @param {string} level - The message level (required). Possible values:
   * ```
   * "info" | "warning" | "error" | "success"
   * ```
   * @param {string} [icon] - The icon to display (optional). Possible values:
   * ```
   * "audio" | "video" | "list" | "ok" | "close" | "power" | "settings" | "home" |
   * "download" | "drive" | "refresh" | "mute" | "volume_mid" | "volume_max" |
   * "image" | "tint" | "prev" | "play" | "pause" | "stop" | "next" | "eject" |
   * "left" | "right" | "plus" | "minus" | "eye_open" | "eye_close" | "warning" |
   * "shuffle" | "up" | "down" | "loop" | "directory" | "upload" | "call" | "cut" |
   * "copy" | "save" | "bars" | "envelope" | "charge" | "paste" | "bell" |
   * "keyboard" | "gps" | "file" | "wifi" | "battery_full" | "battery_3" |
   * "battery_2" | "battery_1" | "battery_empty" | "usb" | "bluetooth" | "trash" |
   * "edit" | "backspace" | "sd_card" | "new_line"
   * ```
   * @param {number} [timeout=2000] - Duration in milliseconds before hiding the message (optional, range: 500-10000).
   * @param {boolean} [waitUser=false] - Whether to wait for user interaction (optional).
   * @throws {Error} If message or level is not provided, or if level/icon/timeout values are invalid.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  showFlexbarSnackbarMessage(serialNumber, msg, level, icon, timeout = 2e3, waitUser = false) {
    const allowedLevels = ["info", "warning", "error", "success"];
    const allowedIcons = [
      "audio",
      "video",
      "list",
      "ok",
      "close",
      "power",
      "settings",
      "home",
      "download",
      "drive",
      "refresh",
      "mute",
      "volume_mid",
      "volume_max",
      "image",
      "tint",
      "prev",
      "play",
      "pause",
      "stop",
      "next",
      "eject",
      "left",
      "right",
      "plus",
      "minus",
      "eye_open",
      "eye_close",
      "warning",
      "shuffle",
      "up",
      "down",
      "loop",
      "directory",
      "upload",
      "call",
      "cut",
      "copy",
      "save",
      "bars",
      "envelope",
      "charge",
      "paste",
      "bell",
      "keyboard",
      "gps",
      "file",
      "wifi",
      "battery_full",
      "battery_3",
      "battery_2",
      "battery_1",
      "battery_empty",
      "usb",
      "bluetooth",
      "trash",
      "edit",
      "backspace",
      "sd_card",
      "new_line",
      "dummy"
    ];
    if (!msg || typeof msg !== "string" || msg.length > 64) {
      throw new Error("Message is required and must be a string with length < 64");
    }
    if (!level || typeof level !== "string") {
      throw new Error("Level is required and must be a string");
    }
    if (!allowedLevels.includes(level)) {
      throw new Error(`Invalid level. Must be one of: ${allowedLevels.join(", ")}`);
    }
    if (icon !== void 0 && !allowedIcons.includes(icon)) {
      throw new Error(`Invalid icon. Must be one of: ${allowedIcons.join(", ")}`);
    }
    if (timeout < 500 || timeout > 1e4) {
      throw new Error("Timeout must be between 500 and 10000 milliseconds");
    }
    const payload = {
      serialNumber,
      msg,
      level,
      timeout,
      waitUser
    };
    if (icon !== void 0) {
      payload.icon = icon;
    }
    return this.transport.call("show-snackbar-message", payload);
  }
  /**
   * @brief Update shortcuts.
   *
   * Detailed description:
   * This method sends a command to update the shortcuts.
   *
   * Shortcut values can be referenced from https://www.electronjs.org/docs/latest/api/accelerator
   *
   * @param {Array<Object>} shortcuts - The shortcuts to update.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  updateShortcuts(shortcuts) {
    return this.transport.call("update-shortcuts", { shortcuts });
  }
  /**
   * @brief Set the state for a multistate key.
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @param {number} state - The next state.
   * @param {string?} message - Optional message to display on the bar.
   * @throws {Error} If the provided data is invalid for the given key type.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  setMultiState(serialNumber, key, state, message) {
    if (key.cfg.keyType !== "multiState") {
      throw new Error(`Invalid key type: ${key.cfg.keyType}`);
    }
    return this.transport.call("set", {
      serialNumber,
      key,
      data: { state, message }
    });
  }
  /**
   * @brief Set the value for a slider key.
   * @param {string} serialNumber - The serial number of the device.
   * @param {Object} key - The key object received from the event `plugin.data` or `plugin.alive`.
   * @param {number} value - The slider value to set.
   * @throws {Error} If the provided data is invalid for the given key type.
   * @returns {Promise<any>} A promise that resolves with the server response.
   */
  setSlider(serialNumber, key, value) {
    if (key.cfg.keyType !== "slider") {
      throw new Error(`Invalid key type: ${key.cfg.keyType}`);
    }
    return this.transport.call("set", {
      serialNumber,
      key,
      data: { value }
    });
  }
  /**
   * @deprecated Use `setMultiState` or `setSlider` depending on key type
   */
  set(serialNumber, key, data) {
    return this.transport.call("set", {
      serialNumber,
      key,
      data
    });
  }
  /**
   * @brief Show a snackbar message in the parent window.
   *
   * Detailed description:
   * Displays a transient message (snackbar) with a specified color and timeout.
   *
   * @param {string} color - The color type for the message. Possible values:
   * ```
   * "success" | "info" | "warning" | "error"
   * ```
   * @param {string} message - The message content to display
   * @param {number} [timeout=3000] - Duration in milliseconds before hiding the message
   * @return {Promise<any>} A promise that resolves with the response.
   */
  showSnackbarMessage(color, message, timeout = 3e3) {
    return this.transport.call("ui-operation", {
      type: "showSnackbarMessage",
      data: {
        color,
        message,
        timeout
      }
    });
  }
  /**
   * @brief Call Electron API, see https://www.electronjs.org/docs/latest/api/app for details.
   *
   * Detailed description:
   * This function allows you to call various Electron APIs through a single interface.
   *
   * @param {string} api - The Electron API method to call. Possible values:
   * ```
   * dialog.showOpenDialog
   * dialog.showSaveDialog
   * dialog.showMessageBox
   * dialog.showErrorBox
   * app.getAppPath
   * app.getPath
   * screen.getCursorScreenPoint
   * screen.getPrimaryDisplay
   * screen.getAllDisplays
   * screen.getDisplayNearestPoint
   * screen.getDisplayMatching
   * screen.screenToDipPoint
   * screen.dipToScreenPoint
   * ```
   * @param {...any} args - Arguments to be passed to the Electron API call
   * @returns {Promise<any>} A promise that resolves exactly as the Electron API returns
   * @throws {Error} Throws an error if the call fails
   */
  electronAPI(api, ...args) {
    return this.transport.call("api-call", {
      api: "callElectronAPI",
      args: { api, args }
    }, 0);
  }
  /**
   * @brief Get application information.
   *
   * Detailed description:
   * This function retrieves the application version and platform.
   *
   * @returns {Promise<Object>} A promise that resolves with the app info in JSON format:
   * ```
   * {
   *   "version": "vX.X.X",
   *   "platform": "darwin | win32 | linux"
   * }
   * ```
   * @throws {Error} Throws an error if the call fails
   */
  getAppInfo() {
    return this.transport.call("api-call", {
      api: "getAppInfo",
      args: null
    }, 0);
  }
  /**
   * @brief Open a file from the given path.
   *
   * Detailed description:
   * Retrieves the file content if successful; otherwise throws an error.
   *
   * @param {string} path - The file path
   * @returns {Promise<string|Buffer>} A promise that resolves with the file content
   * @throws {Error} Throws an error if file opening fails
   */
  openFile(path2) {
    return this.transport.call("api-call", {
      api: "openFile",
      args: { path: path2 }
    }, 0);
  }
  /**
   * @brief Save data to a specified file path.
   *
   * Detailed description:
   * Saves string or Buffer data to the provided file path and returns a status.
   *
   * @param {string} path - The file path
   * @param {string|Buffer} data - The file content
   * @returns {Promise<Object>} A promise that resolves with the result in JSON format:
   * ```
   * {
   *   "status": "success" | "error",
   *   "error": "Error message if status is 'error'"
   * }
   * ```
   * @throws {Error} Throws an error if saving fails
   */
  saveFile(path2, data) {
    return this.transport.call("api-call", {
      api: "pluginSaveFile",
      args: { path: path2, data }
    }, 0);
  }
  /**
   * @brief Get the list of opened windows.
   *
   * Detailed description:
   * Retrieves an array of window objects in JSON format, each containing details
   * such as `platform`, `id`, `title`, `owner`, `bounds`, and `memoryUsage`.
   *
   * @returns {Promise<Array<Types.DesktopWindow>>} A promise that resolves to an array of window objects.
   * @throws {Error} Throws an error if the call fails
   */
  getOpenedWindows() {
    return this.transport.call("api-call", {
      api: "getOpenedWindows",
      args: null
    }, 0);
  }
  /**
   * @brief Get the device status.
   *
   * Detailed description:
   * Returns a JSON object containing various status fields such as
   * `connecting`, `connected`, `serialNumber`, `platform`, `profileVersion`,
   * and `fwVersion`.
   *
   * @returns {Promise<Array<Types.DeviceStatusResponseItem>>} A promise that resolves to a JSON object.
   * @throws {Error} Throws an error if the call fails
   */
  getDeviceStatus() {
    return this.transport.call("api-call", {
      api: "getDeviceStatus",
      args: null
    }, 0);
  }
  /**
   * @brief Set device configuration
   *
   * @param {string} serialNumber - The serial number of the device
   * @param {Types.DeviceConfigInput} config Device configuration object. See comments in `DeviceConfigInput` for details.
   * @returns {Promise<any>} Promise that resolves with the result
   */
  setDeviceConfig(serialNumber, config) {
    return this.transport.call("device-config", {
      serialNumber,
      config
    });
  }
  /**
   * @brief Get the plugin configuration.
   *
   * @returns {Promise<Object>} A promise that resolves to the plugin configuration object.
   * @throws {Error} Throws an error if the call fails
   */
  getConfig() {
    return this.transport.call("api-call", {
      api: "getPluginConfig",
      pluginID: this.uuid
    }, 0);
  }
  /**
   * @brief Set the plugin configuration.
   *
   * @param {Object} config The plugin configuration object.
   * @returns {Promise<Object>} A promise that resolves to the result { status: 'success' | 'error }.
   * @throws {Error} Throws an error if the call fails
   */
  setConfig(config) {
    return this.transport.call("api-call", {
      api: "setPluginConfig",
      pluginID: this.uuid,
      config
    }, 0);
  }
};
var plugin = new Plugin();
var plugin_client_default = plugin;

// node_modules/@eniac/flexdesigner/dist/index.js
var resourcesPath = require("node:path").join((() => {
  const v = process.argv.find((x) => x.startsWith("--dir="));
  const i = process.argv.indexOf("--dir");
  return v ? v.slice(6) : i >= 0 ? process.argv[i + 1] : require("node:path").resolve(__dirname, "..");
})(), "resources");
var pluginPath = (() => {
  const v = process.argv.find((x) => x.startsWith("--dir="));
  const i = process.argv.indexOf("--dir");
  return v ? v.slice(6) : i >= 0 ? process.argv[i + 1] : require("node:path").resolve(__dirname, "..");
})();

// src/clock.mjs
var monotonic = () => Number(process.hrtime.bigint()) / 1e9;
var PlaybackClock = class {
  constructor(now = monotonic) {
    this.now = now;
    this.offset = null;
    this.rtt = null;
    this.anchor = null;
  }
  synchronize({ echoClientTime, serverUptime }, received = this.now()) {
    if (!Number.isFinite(echoClientTime) || !Number.isFinite(serverUptime) || received < echoClientTime) throw new Error("Invalid clock synchronization");
    this.rtt = received - echoClientTime;
    this.offset = serverUptime - (echoClientTime + received) / 2;
  }
  update(anchor) {
    this.anchor = anchor ?? null;
  }
  position(now = this.now()) {
    if (!this.anchor) return 0;
    if (this.offset == null || !this.anchor.rate) return this.anchor.position;
    return Math.max(0, this.anchor.position + (now + this.offset - this.anchor.hostUptime) * this.anchor.rate);
  }
  reset() {
    this.anchor = null;
    this.offset = null;
    this.rtt = null;
  }
};

// src/bridge.mjs
var import_node_net = __toESM(require("node:net"), 1);
var import_node_os = __toESM(require("node:os"), 1);
var import_node_path = __toESM(require("node:path"), 1);
var import_node_crypto = require("node:crypto");

// src/codec.mjs
var MAX_FRAME = 65536;
var graphemes = (text) => [...new Intl.Segmenter(void 0, { granularity: "grapheme" }).segment(text)].map((x) => x.segment);
var JsonLines = class {
  constructor(onFrame) {
    this.pending = Buffer.alloc(0);
    this.onFrame = onFrame;
  }
  push(chunk) {
    this.pending = Buffer.concat([this.pending, chunk]);
    let end;
    while ((end = this.pending.indexOf(10)) >= 0) {
      if (end > MAX_FRAME) throw new Error("Frame exceeds 64 KiB");
      const frame = this.pending.subarray(0, end);
      this.pending = this.pending.subarray(end + 1);
      this.onFrame(JSON.parse(frame.toString("utf8")));
    }
    if (this.pending.length > MAX_FRAME) throw new Error("Incomplete frame exceeds 64 KiB");
  }
};
function validateSnapshot(value) {
  if (!value || value.version !== 1 || value.kind !== "snapshot" || typeof value.sessionID !== "string" || !Number.isSafeInteger(value.revision)) throw new Error("Invalid snapshot envelope");
  if (!["idle", "loading", "lyrics", "song", "instrumental", "notFound"].includes(value.state)) throw new Error("Invalid content state");
  for (const key of ["title", "artist", "primary", "translation", "nextLine"]) {
    if (value[key] != null && (typeof value[key] !== "string" || graphemes(value[key]).length > 4096 || Buffer.byteLength(value[key]) > 8192)) throw new Error("Invalid text field");
  }
  if (value.clock && (!Number.isFinite(value.clock.hostUptime) || !Number.isFinite(value.clock.position) || ![0, 1].includes(value.clock.rate))) throw new Error("Invalid clock");
  if (value.timing) {
    const timing = value.timing, count = graphemes(value.primary).length;
    if (!Number.isFinite(timing.start) || !Number.isFinite(timing.end) || !Number.isFinite(timing.offsetMilliseconds) || !Array.isArray(timing.words) || timing.words.length > 128) throw new Error("Invalid timing");
    for (const word of timing.words) if (!Number.isInteger(word.location) || !Number.isInteger(word.length) || word.location < 0 || word.length < 1 || word.location + word.length > count || !Number.isFinite(word.start) || !Number.isFinite(word.end) || word.end < word.start) throw new Error("Invalid word range");
  }
  return value;
}
function presentationSignature(s) {
  return JSON.stringify([s.state, s.primary, s.translation, s.nextLine, s.title, s.artist, s.timing]);
}

// src/bridge.mjs
var LyricsBridge = class {
  constructor({ onSnapshot, onSync, onStatus, socketPath = import_node_path.default.join(import_node_os.default.homedir(), "Library/Application Support/LyricsX Next/Flexbar/bridge.sock"), connect = (options) => import_node_net.default.createConnection(options), now = monotonic }) {
    Object.assign(this, { onSnapshot, onSync, onStatus, socketPath, connect, now });
    this.active = false;
    this.socket = null;
    this.retry = null;
    this.attempt = 0;
    this.session = null;
    this.revision = -1;
    this.generation = 0;
  }
  setActive(active) {
    if (active === this.active) return;
    this.active = active;
    if (active) this.open();
    else this.stop();
  }
  open() {
    if (!this.active || this.socket) return;
    const token = ++this.generation, nonce = (0, import_node_crypto.randomUUID)();
    this.nonce = nonce;
    const socket = this.connect({ path: this.socketPath });
    this.socket = socket;
    const parser = new JsonLines((frame) => {
      if (frame.kind === "clockSync") {
        if (frame.nonce !== nonce) throw new Error("Clock nonce mismatch");
        this.onSync(frame);
        return;
      }
      const snapshot = validateSnapshot(frame);
      if (snapshot.sessionID !== this.session) {
        this.session = snapshot.sessionID;
        this.revision = -1;
      }
      if (snapshot.revision <= this.revision) return;
      this.revision = snapshot.revision;
      this.attempt = 0;
      this.onStatus("connected");
      this.onSnapshot(snapshot);
    });
    socket.on("connect", () => {
      if (this.generation !== token) return;
      socket.write(JSON.stringify({ version: 1, kind: "subscribe", clientTime: this.now(), nonce }) + "\n");
    });
    socket.on("data", (chunk) => {
      if (this.generation !== token) return;
      try {
        parser.push(chunk);
      } catch {
        socket.destroy();
      }
    });
    socket.on("error", () => {
    });
    socket.on("close", () => {
      if (this.generation !== token) return;
      this.socket = null;
      this.session = null;
      this.revision = -1;
      this.onStatus("disconnected");
      if (this.active && !this.retry) {
        const delay = Math.min(3e4, 1e3 * 2 ** Math.min(this.attempt++, 5));
        this.retry = setTimeout(() => {
          this.retry = null;
          this.open();
        }, delay);
      }
    });
  }
  stop() {
    this.active = false;
    this.generation++;
    clearTimeout(this.retry);
    this.retry = null;
    this.socket?.destroy();
    this.socket = null;
    this.session = null;
    this.revision = -1;
  }
};

// src/renderer.mjs
var import_canvas = require("@napi-rs/canvas");
var import_node_crypto2 = require("node:crypto");
import_canvas.GlobalFonts.loadSystemFonts();
var FONT = '"Hiragino Sans GB"';
var EMOJI_FONT = '"Apple Color Emoji"';
var cache = /* @__PURE__ */ new Map();
var cacheBytes = 0;
var MAX_CACHE_BYTES = 16 * 1024 * 1024;
var metricsMeasurements = 0;
var measureContext = (0, import_canvas.createCanvas)(1, 1).getContext("2d");
function runs(text, size) {
  const result = [];
  let textRun = "", emojiRun = null;
  const flush = () => {
    if (textRun) {
      const font = `${size}px ${emojiRun ? EMOJI_FONT : FONT}`;
      measureContext.font = font;
      metricsMeasurements++;
      const m = measureContext.measureText(textRun);
      result.push({ text: textRun, font, width: m.width, ascent: m.actualBoundingBoxAscent, descent: m.actualBoundingBoxDescent });
      textRun = "";
    }
  };
  for (const char of graphemes(text)) {
    const emoji = new RegExp("\\p{Extended_Pictographic}|\\p{Regional_Indicator}|\\u20e3", "u").test(char);
    if (emoji !== emojiRun) {
      flush();
      emojiRun = emoji;
    }
    textRun += char;
  }
  flush();
  return result;
}
function row(text, size, color, width) {
  const shaped = runs(text, size), ascent = Math.max(0, ...shaped.map((run) => run.ascent)), descent = Math.max(0, ...shaped.map((run) => run.descent));
  const canvas = (0, import_canvas.createCanvas)(Math.max(1, Math.ceil(width) + 4), Math.max(1, Math.ceil(ascent + descent) + 4)), ctx = canvas.getContext("2d");
  ctx.fillStyle = color;
  ctx.textBaseline = "alphabetic";
  let x = 2;
  for (const run of shaped) {
    ctx.font = run.font;
    ctx.fillText(run.text, x, ascent + 2);
    x += run.width;
  }
  return canvas;
}
function measure(text, size) {
  return runs(text, size).reduce((sum, run) => sum + run.width, 0);
}
var pages = (text) => {
  const chars = graphemes(text ?? "");
  const result = [];
  for (let i = 0; i < chars.length; i += 400) result.push({ text: chars.slice(i, i + 400).join(""), location: i });
  return result.length ? result : [{ text: "", location: 0 }];
};
var statusText = (s) => s.suspended ? "\u7761\u7720\u4E2D" : !s.isPlaying && s.state !== "idle" ? "\u5DF2\u6682\u505C" : { idle: "\u8BF7\u5728 LyricsX Next \u64AD\u653E\u6B4C\u66F2", loading: "\u6B63\u5728\u5BFB\u627E\u6B4C\u8BCD", instrumental: "\u7EAF\u97F3\u4E50", notFound: "\u672A\u627E\u5230\u6B4C\u8BCD", song: s.artist || "\u95F4\u594F" }[s.state] || "";
function readingPages(text, size, available) {
  const chars = graphemes(text ?? ""), result = [];
  let start = 0;
  while (start < chars.length) {
    let end = start + 1;
    while (end < chars.length && measure(chars.slice(start, end + 1).join(""), size) <= available) end++;
    result.push({ text: chars.slice(start, end).join(""), location: start });
    start = end;
  }
  return result.length ? result : [{ text: "", location: 0 }];
}
function auxiliaryText(snapshot, options) {
  if (options.secondary === "off") return "";
  if (options.secondary === "next") return snapshot.nextLine?.trim() ? snapshot.nextLine : "";
  return snapshot.translation?.trim() ? snapshot.translation : snapshot.nextLine?.trim() ? snapshot.nextLine : snapshot.state === "lyrics" ? "" : statusText(snapshot);
}
function layout(snapshot, width, options, page, manual) {
  const auxiliary = auxiliaryText(snapshot, options), single = !auxiliary.trim(), size = single ? 36 : 26;
  const signature = JSON.stringify([presentationSignature(snapshot), width, options.secondary, page, manual, auxiliary]);
  if (cache.has(signature)) {
    const value2 = cache.get(signature);
    cache.delete(signature);
    cache.set(signature, value2);
    return value2;
  }
  const primaryReading = readingPages(snapshot.primary, size, width - 24), secondaryReading = readingPages(auxiliary, 18, width - 64);
  const primaryPages = manual ? primaryReading : pages(snapshot.primary), secondaryPages = manual ? secondaryReading : pages(auxiliary);
  const count = Math.max(primaryPages.length, secondaryPages.length), currentPage = page % count;
  const main = primaryPages[currentPage % primaryPages.length], second = secondaryPages[currentPage % secondaryPages.length];
  const secondary = second.text, mainWidth = measure(main.text, size), secondaryWidth = measure(secondary, 18), chars = graphemes(main.text);
  let prefix = "", advances = [0];
  for (const character of chars) {
    prefix += character;
    advances.push(measure(prefix, size));
  }
  const ranges = (snapshot.timing?.words ?? []).flatMap((word) => {
    const start = Math.max(0, word.location - main.location), end = Math.min(chars.length, word.location + word.length - main.location);
    return end > start ? [{ ...word, x: advances[start], width: advances[end] - advances[start] }] : [];
  });
  const primary = row(main.text, size, "#8a9aaa", mainWidth), lit = row(main.text, size, "#f6fbff", mainWidth), secondaryRow = row(secondary, 18, "#c1cddd", secondaryWidth);
  const value = {
    primary,
    lit,
    secondary: secondaryRow,
    mainWidth,
    secondaryWidth,
    ranges,
    single,
    size,
    pageCount: count,
    readingPageCount: Math.max(primaryReading.length, secondaryReading.length),
    pageText: main.text,
    pageLocation: main.location,
    readingFirstText: primaryReading[0].text,
    bytes: primary.width * primary.height * 8 + secondaryRow.width * secondaryRow.height * 4
  };
  cache.set(signature, value);
  cacheBytes += value.bytes;
  while (cacheBytes > MAX_CACHE_BYTES && cache.size > 1) {
    const key = cache.keys().next().value;
    cacheBytes -= cache.get(key).bytes;
    cache.delete(key);
  }
  return value;
}
function scroll(width, available, elapsed, playing) {
  if (width <= available) return 0;
  const distance = width - available, travel = distance / 34, cycle = travel * 2 + 1.4;
  const t = Math.max(0, elapsed) % cycle;
  if (t < 0.7) return 0;
  if (t < 0.7 + travel) return (t - 0.7) * 34;
  if (t < 1.4 + travel) return distance;
  return Math.max(0, distance - (t - 1.4 - travel) * 34);
}
function scrollDelay(width, available, elapsed, frameDelay) {
  if (width <= available) return null;
  const travel = (width - available) / 34, t = Math.max(0, elapsed) % (travel * 2 + 1.4);
  if (t < 0.7) return (0.7 - t) * 1e3;
  if (t >= 0.7 + travel && t < 1.4 + travel) return (1.4 + travel - t) * 1e3;
  return frameDelay;
}
var Renderer = class {
  constructor() {
    this.reset();
  }
  reset() {
    this.signature = null;
    this.started = 0;
    this.previous = null;
    this.lastLayout = null;
    this.lastLayer = null;
    this.page = 0;
    this.frozenElapsed = 0;
    this.playing = false;
    this.content = null;
    this.manualPage = false;
    this.readingPageCount = 1;
  }
  nextPage() {
    if (this.readingPageCount <= 1) {
      this.manualPage = false;
      this.page = 0;
      return;
    }
    if (!this.manualPage) {
      this.manualPage = true;
      this.page = 1;
    } else if (this.page + 1 >= this.readingPageCount) {
      this.manualPage = false;
      this.page = 0;
    } else this.page++;
  }
  render(snapshot, width, position, now, options = { secondary: "translation", fps: 30 }) {
    width = Math.max(120, Math.min(2170, Math.round(width)));
    const content = presentationSignature(snapshot) + snapshot.trackRevision;
    if (content !== this.content) {
      this.page = 0;
      this.manualPage = false;
      this.content = content;
    }
    const lyricTime = position + (snapshot.timing?.offsetMilliseconds ?? 0) / 1e3;
    if (!this.manualPage && snapshot.isPlaying && snapshot.timing?.words.length) {
      const cue = [...snapshot.timing.words].reverse().find((cue2) => lyricTime >= cue2.start);
      if (cue) this.page = Math.floor(cue.location / 400);
    }
    const signature = content + JSON.stringify([width, options.secondary, this.page, this.manualPage, options.alignment]);
    if (signature !== this.signature) {
      this.previous = this.lastLayer;
      this.started = now;
      this.frozenElapsed = 0;
      this.signature = signature;
    }
    let elapsed = now - this.started;
    if (!snapshot.isPlaying || snapshot.suspended) {
      if (this.playing) this.frozenElapsed = elapsed;
      elapsed = this.frozenElapsed;
    } else if (!this.playing && this.lastLayout) {
      this.started = now - this.frozenElapsed;
      elapsed = this.frozenElapsed;
    }
    this.playing = snapshot.isPlaying && !snapshot.suspended;
    const current = layout(snapshot, width, options, this.page, this.manualPage);
    this.lastLayout = current;
    this.readingPageCount = current.readingPageCount;
    const canvas = (0, import_canvas.createCanvas)(width, 60), ctx = canvas.getContext("2d");
    ctx.fillStyle = "#081321";
    ctx.fillRect(0, 0, width, 60);
    if (!options.immersive) {
      ctx.fillStyle = "#28435d";
      ctx.fillRect(0, 0, 3, 60);
    }
    const available = width - 24;
    let mainScroll = scroll(current.mainWidth, available, elapsed);
    if (current.mainWidth > available && snapshot.timing) {
      const cue = [...current.ranges].reverse().find((cue2) => lyricTime >= cue2.start);
      if (cue) {
        const progress2 = cue.end === cue.start ? 1 : Math.max(0, Math.min(1, (lyricTime - cue.start) / (cue.end - cue.start)));
        mainScroll = Math.max(0, Math.min(current.mainWidth - available, cue.x + cue.width * progress2 - available * 0.55));
      } else if (!current.ranges.length && snapshot.timing.end > snapshot.timing.start) {
        const budget = snapshot.timing.end - snapshot.timing.start;
        mainScroll = Math.max(0, Math.min(1, (lyricTime - snapshot.timing.start) / Math.max(0.1, budget - 0.3))) * (current.mainWidth - available);
      }
    }
    const auxScroll = scroll(current.secondaryWidth, available, elapsed);
    const alignment = options.alignment ?? (options.immersive ? "center" : "left");
    const aligned = (textWidth, offset) => alignment === "center" && textWidth <= available ? (width - textWidth) / 2 - 2 : 10 - offset;
    const geometry = { mainX: aligned(current.mainWidth, mainScroll), secondaryX: aligned(current.secondaryWidth, auxScroll), primaryY: current.single ? (60 - current.primary.height) / 2 : 1, secondaryY: 33, mainScroll, auxScroll, time: lyricTime, lyrical: snapshot.state === "lyrics" };
    const paint = (layer2, alpha, shift) => {
      const { item, g } = layer2;
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.beginPath();
      ctx.rect(12, 0, available, 60);
      ctx.clip();
      ctx.drawImage(item.primary, g.mainX, g.primaryY + shift);
      if (g.lyrical && !item.ranges.length) ctx.drawImage(item.lit, g.mainX, g.primaryY + shift);
      else for (const cue of item.ranges) {
        const progress2 = cue.end === cue.start ? Number(g.time >= cue.start) : Math.max(0, Math.min(1, (g.time - cue.start) / (cue.end - cue.start)));
        if (!progress2) continue;
        ctx.save();
        ctx.beginPath();
        ctx.rect(g.mainX + 2 + cue.x, 0, cue.width * progress2, 60);
        ctx.clip();
        ctx.drawImage(item.lit, g.mainX, g.primaryY + shift);
        ctx.restore();
      }
      if (!item.single) ctx.drawImage(item.secondary, g.secondaryX, g.secondaryY + shift);
      ctx.restore();
    };
    const entryDuration = Math.min(0.18, Math.max(0.01, (snapshot.timing ? snapshot.timing.end - snapshot.timing.start : 1) * 0.2));
    const transition = this.previous && this.playing && elapsed < entryDuration && (!snapshot.timing || snapshot.timing.end - snapshot.timing.start >= 0.35);
    const progress = Math.min(1, elapsed / entryDuration), eased = 1 - (1 - progress) ** 3, layer = { item: current, g: geometry };
    paint(layer, transition ? 0.9 + 0.1 * eased : 1, transition ? 2 * (1 - eased) : 0);
    this.lastLayer = layer;
    if (!snapshot.isPlaying && snapshot.state !== "idle") {
      ctx.fillStyle = "#aebed0";
      ctx.fillRect(width - 9, 7, 2, 8);
      ctx.fillRect(width - 5, 7, 2, 8);
    }
    let nextDelay = null;
    if (this.playing) {
      const changingWord = current.ranges.some((cue) => lyricTime >= cue.start && lyricTime < cue.end), frameDelay = 1e3 / ([15, 20, 30, 60].filter((fps) => fps <= Number(options.fps || 30)).pop() || 15), delays = [];
      if (transition || changingWord) delays.push(frameDelay);
      if (current.mainWidth > available) {
        if (snapshot.timing) {
          if (!current.ranges.length && lyricTime >= snapshot.timing.start && lyricTime < snapshot.timing.end - 0.3) delays.push(frameDelay);
        } else {
          const delay = scrollDelay(current.mainWidth, available, elapsed, frameDelay);
          if (delay != null) delays.push(delay);
        }
      }
      const auxDelay = scrollDelay(current.secondaryWidth, available, elapsed, frameDelay);
      if (auxDelay != null) delays.push(auxDelay);
      delays.push(...current.ranges.filter((cue) => cue.start > lyricTime).map((cue) => (cue.start - lyricTime) * 1e3));
      if (delays.length) nextDelay = Math.min(...delays);
    }
    let output = canvas;
    if (options.immersive && options.rotation === 180) {
      output = (0, import_canvas.createCanvas)(width, 60);
      const rotated = output.getContext("2d");
      rotated.imageSmoothingEnabled = false;
      rotated.translate(width, 60);
      rotated.rotate(Math.PI);
      rotated.drawImage(canvas, 0, 0);
    }
    const png = output.toBuffer("image/png");
    return { png, signature: (0, import_node_crypto2.createHash)("sha256").update(png).digest("hex"), nextDelay, pageCount: current.pageCount, readingPageCount: current.readingPageCount, width, height: 60, mainScroll, ranges: current.ranges, pageText: current.pageText, pageLocation: current.pageLocation, readingFirstText: current.readingFirstText, geometry, single: current.single, fontSize: current.size, rowHeight: current.primary.height };
  }
};

// src/scheduler.mjs
var DrawScheduler = class {
  constructor({ render, draw, onError = () => {
  }, now = () => performance.now(), setTimer = setTimeout, clearTimer = clearTimeout }) {
    Object.assign(this, { render, draw, onError, now, setTimer, clearTimer });
    this.active = true;
    this.timer = null;
    this.busy = false;
    this.latest = false;
    this.successSignature = null;
    this.lastRender = null;
    this.latency = 0;
    this.failures = 0;
    this.drawCount = 0;
    this.skipped = 0;
    this.generation = 0;
  }
  request() {
    if (!this.active) return;
    this.clearTimer(this.timer);
    this.timer = null;
    if (this.busy) {
      this.latest = true;
      return;
    }
    this.run();
  }
  async run() {
    if (!this.active || this.busy) return;
    const frameStarted = this.now();
    const result = this.render();
    this.lastRender = result;
    if (result.signature === this.successSignature) {
      this.skipped++;
      this.schedule(result.nextDelay, this.now() - frameStarted);
      return;
    }
    this.busy = true;
    this.latest = false;
    const token = this.generation, start = this.now();
    try {
      await this.draw(result);
      if (this.active && this.generation === token) {
        this.successSignature = result.signature;
        this.failures = 0;
        this.drawCount++;
        this.latency = this.now() - start;
      }
    } catch (error) {
      if (this.active && this.generation === token) {
        this.failures++;
        this.onError(error);
      }
    } finally {
      this.busy = false;
      if (!this.active || this.generation !== token) return;
      if (this.failures) {
        this.schedule(Math.min(1e4, 250 * 2 ** Math.min(this.failures - 1, 5)));
      } else if (this.latest) {
        this.latest = false;
        this.run();
      } else this.schedule(result.nextDelay, this.now() - frameStarted);
    }
  }
  schedule(delay, elapsed = 0) {
    if (!this.active || delay == null) return;
    this.clearTimer(this.timer);
    this.timer = this.setTimer(() => {
      this.timer = null;
      this.run();
    }, Math.max(0, Math.max(delay, this.latency * 1.15) - elapsed));
  }
  stop() {
    this.active = false;
    this.generation++;
    this.latest = false;
    this.clearTimer(this.timer);
    this.timer = null;
  }
  get pendingFrames() {
    return Number(this.busy) + Number(this.latest);
  }
};

// src/lifecycle.mjs
var UUID = "com.wzk112.lyricsxnext";
var KEY_CARD = UUID + ".lyrics";
var KEY_SCREEN = UUID + ".immersive";
var idle = () => ({ version: 1, kind: "snapshot", sessionID: "offline", revision: 0, state: "idle", title: "", artist: "", primary: "\u8BF7\u6253\u5F00 LyricsX Next", translation: "\u5728\u8BBE\u7F6E\u4E2D\u542F\u7528 Flexbar", isPlaying: false, suspended: false });
var normalizedFlip = (value) => typeof value === "boolean" ? value : value === 0 ? false : value === 1 ? true : void 0;
var LyricsPlugin = class {
  constructor(plugin2, { bridgeFactory = (options) => new LyricsBridge(options), now = monotonic, logger: logger3 = { warn: () => {
  } } } = {}) {
    Object.assign(this, { plugin: plugin2, now, logger: logger3 });
    this.keys = /* @__PURE__ */ new Map();
    this.devices = /* @__PURE__ */ new Map();
    this.clock = new PlaybackClock(now);
    this.snapshot = idle();
    this.hostGeneration = 0;
    this.statusRequest = null;
    this.statusFollowup = false;
    this.statusDiagnosticGeneration = -1;
    this.lastTouch = /* @__PURE__ */ new Map();
    this.bridge = bridgeFactory({ onSnapshot: (s) => this.receive(s), onSync: (s) => this.clock.synchronize(s), onStatus: (status) => {
      if (status === "disconnected") {
        this.clock.reset();
        this.snapshot = idle();
        this.requestAll();
      }
    } });
    plugin2.on("plugin.alive", (p) => this.alive(p));
    plugin2.on("plugin.dead", (p) => this.dead(p));
    plugin2.on("device.status", (devices) => this.deviceStatus(devices));
    plugin2.on("device.touch", (payload) => {
      if (payload.state !== "up" && payload.state !== "end") return;
      const now2 = this.now(), last = this.lastTouch.get(payload.serialNumber) ?? -Infinity;
      if (now2 - last < 0.25) return;
      this.lastTouch.set(payload.serialNumber, now2);
      for (const item of this.keys.values()) if (item.serialNumber === payload.serialNumber && item.key.cid === KEY_SCREEN) {
        item.renderer.nextPage();
        item.scheduler.request();
      }
    });
    plugin2.on("plugin.data", (p) => {
      const item = this.keys.get(this.identity(p.serialNumber, p.data?.key));
      if (item && p.data?.evt === "click") {
        item.renderer.nextPage();
        item.scheduler.request();
      }
      return { status: "success" };
    });
  }
  identity(serial, key) {
    return `${serial}:${key?.uid}`;
  }
  options(key) {
    const data = key.data ?? {}, immersive = key.cid === KEY_SCREEN;
    return {
      secondary: ["translation", "next", "off"].includes(data.secondary) ? data.secondary : "translation",
      fps: [15, 20, 30, 60].includes(Number(data.fps)) ? Number(data.fps) : 30,
      diffUpdate: data.diffUpdate === true,
      immersive,
      orientation: ["auto", "normal", "flipped"].includes(data.orientation) ? data.orientation : "auto",
      alignment: ["center", "left"].includes(data.alignment) ? data.alignment : immersive ? "center" : "left",
      rotation: 0
    };
  }
  effectiveRotation(serial, options) {
    return options.immersive && (options.orientation === "flipped" || options.orientation === "auto" && this.devices.get(serial)?.screenFlip === true) ? 180 : 0;
  }
  applyDeviceFlip(serial, flip) {
    flip = normalizedFlip(flip);
    if (typeof flip !== "boolean") return;
    const record = this.devices.get(serial) ?? { revision: 0 };
    const first = record.screenFlip === void 0;
    record.screenFlip = flip;
    this.devices.set(serial, record);
    if (first) this.logger.info?.(`Flexbar screenFlip: ${flip}`);
    for (const item of this.keys.values()) if (item.serialNumber === serial) {
      const rotation = this.effectiveRotation(serial, item.options);
      if (rotation !== item.options.rotation) {
        item.options.rotation = rotation;
        item.orientationRevision++;
        item.scheduler.request();
      }
    }
  }
  hostReady() {
    this.logger.info?.("Flexbar hostReady: requesting device orientation");
    this.refreshDeviceStatus();
  }
  refreshDeviceStatus(needsFollowup = false) {
    if (!this.plugin.transport?.call) return Promise.resolve();
    if (this.statusRequest) {
      if (needsFollowup) this.statusFollowup = true;
      return this.statusRequest;
    }
    const generation = this.hostGeneration, revisions = new Map([...this.devices].map(([serial, record]) => [serial, record.revision]));
    const request = Promise.resolve().then(() => generation === this.hostGeneration ? this.plugin.transport.call("api-call", { api: "getDeviceStatus", args: null }, 5e3) : []).then((devices) => {
      if (generation !== this.hostGeneration) return;
      if (this.statusDiagnosticGeneration !== generation) {
        this.statusDiagnosticGeneration = generation;
        const keys = (value) => value && typeof value === "object" ? Object.keys(value) : [];
        const shape = { type: devices === null ? "null" : Array.isArray(devices) ? "array" : typeof devices, count: Array.isArray(devices) ? devices.length : null, keys: keys(devices) };
        if (Array.isArray(devices)) shape.devices = devices.map((device) => {
          const serial = device?.serialNumber, current = this.devices.get(serial), flip = device?.deviceData?.config?.screenFlip;
          const safeFlip = typeof flip === "boolean" || typeof flip === "number" && Number.isFinite(flip) || typeof flip === "string" && ["true", "false", "0", "1"].includes(flip) ? flip : flip === void 0 ? "missing" : "unknown";
          const skipped = typeof serial !== "string" ? "invalidSerial" : current?.connected === false ? "disconnected" : (current?.revision ?? 0) !== (revisions.get(serial) ?? 0) ? "staleRevision" : null;
          return { serialNumber: typeof serial === "string" ? serial : null, keys: keys(device), deviceDataKeys: keys(device?.deviceData), configKeys: keys(device?.deviceData?.config), flipType: typeof flip, screenFlip: safeFlip, skipped };
        });
        this.logger.info?.("Flexbar getDeviceStatus shape: " + JSON.stringify(shape));
      }
      if (!Array.isArray(devices) || !devices.length) {
        this.logger.warn("Flexbar automatic orientation unknown: device status is not a nonempty array");
        return;
      }
      for (const device of devices) {
        if (!device || typeof device.serialNumber !== "string") continue;
        const current = this.devices.get(device.serialNumber);
        if (current?.connected === false) continue;
        if ((current?.revision ?? 0) !== (revisions.get(device.serialNumber) ?? 0)) continue;
        const flip = normalizedFlip(device.deviceData?.config?.screenFlip);
        if (flip === void 0) this.logger.warn("Flexbar automatic orientation unknown: screenFlip missing for " + device.serialNumber);
        this.applyDeviceFlip(device.serialNumber, flip);
      }
    }).catch((error) => {
      if (generation === this.hostGeneration) this.logger.warn("Cannot read Flexbar screen orientation: " + error.message);
    }).finally(() => {
      if (this.statusRequest === request) this.statusRequest = null;
      if (generation === this.hostGeneration && this.statusFollowup) {
        this.statusFollowup = false;
        this.refreshDeviceStatus();
      }
    });
    this.statusRequest = request;
    return request;
  }
  deviceStatus(devices) {
    for (const device of devices ?? []) {
      const record = this.devices.get(device.serialNumber) ?? { revision: 0 };
      record.revision++;
      if (device.status === "connected" || device.status === "disconnected") record.connected = device.status === "connected";
      this.devices.set(device.serialNumber, record);
      if (device.status === "disconnected") {
        record.screenFlip = void 0;
        this.removeDevice(device.serialNumber);
        continue;
      }
      if (normalizedFlip(device.deviceData?.config?.screenFlip) !== void 0) this.applyDeviceFlip(device.serialNumber, device.deviceData.config.screenFlip);
      else if (this.statusRequest) this.statusFollowup = true;
      else if ([...this.keys.values()].some((item) => item.serialNumber === device.serialNumber && item.options.immersive)) this.refreshDeviceStatus();
    }
  }
  alive({ serialNumber, keys }) {
    const record = this.devices.get(serialNumber) ?? { revision: 0 };
    record.connected = true;
    this.devices.set(serialNumber, record);
    let immersive = false;
    for (const key of keys ?? []) {
      if (![KEY_CARD, KEY_SCREEN].includes(key.cid)) continue;
      const identity = this.identity(serialNumber, key);
      this.keys.get(identity)?.scheduler.stop();
      const renderer = new Renderer(), options = this.options(key), width = options.immersive ? 2170 : Math.max(120, Math.min(1e3, Number(key.width || key.style?.width || 720)));
      options.rotation = this.effectiveRotation(serialNumber, options);
      immersive ||= options.immersive;
      const item = { key, renderer, serialNumber, options, orientationRevision: 0, completedOrientationRevision: -1, scheduler: null, drawMeasurements: { samples: 0, total: 0, max: 0 } };
      item.scheduler = new DrawScheduler({ render: () => renderer.render(this.snapshot, width, this.clock.position(), this.now(), options), draw: async (frame) => {
        const revision = item.orientationRevision, data = "data:image/png;base64," + frame.png.toString("base64"), started = this.now();
        if (options.immersive) await this.plugin.directDraw(serialNumber, key, data, options.diffUpdate && item.completedOrientationRevision === revision, 0);
        else await this.plugin.draw(serialNumber, key, "base64", data);
        if (this.keys.get(identity) === item && item.drawMeasurements.samples < 30) {
          const stats = item.drawMeasurements, duration = Math.max(0, (this.now() - started) * 1e3);
          stats.samples++;
          stats.total += duration;
          stats.max = Math.max(stats.max, duration);
          if (stats.samples === 1 || stats.samples === 30) this.logger.info?.("Flexbar draw API ACK (not physical display): " + JSON.stringify({ serialNumber, uid: key.uid, mode: options.immersive ? "directDraw" : "card", samples: stats.samples, meanMilliseconds: stats.total / stats.samples, maxMilliseconds: stats.max }));
        }
        if (this.keys.get(identity) === item && item.orientationRevision === revision) item.completedOrientationRevision = revision;
      }, onError: (error) => this.logger.warn("Flexbar draw failed: " + error.message) });
      this.keys.set(identity, item);
      item.scheduler.request();
    }
    this.reconcileDemand();
    if (immersive) this.refreshDeviceStatus(true);
  }
  reconcileDemand() {
    const active = this.keys.size > 0;
    if (!active) {
      this.clock.reset();
      this.snapshot = idle();
    }
    this.bridge.setActive(active);
  }
  dead({ serialNumber, keys }) {
    for (const key of keys ?? []) this.remove(this.identity(serialNumber, key));
    this.reconcileDemand();
  }
  remove(identity) {
    const item = this.keys.get(identity);
    if (item) {
      item.scheduler.stop();
      this.keys.delete(identity);
    }
  }
  removeDevice(serial) {
    this.lastTouch.delete(serial);
    for (const [identity, item] of this.keys) if (item.serialNumber === serial) this.remove(identity);
    this.reconcileDemand();
  }
  receive(snapshot) {
    if (snapshot.sessionID !== this.snapshot.sessionID) {
      for (const item of this.keys.values()) item.renderer.reset();
    }
    this.snapshot = snapshot;
    this.clock.update(snapshot.clock);
    this.requestAll();
  }
  requestAll() {
    for (const item of this.keys.values()) item.scheduler.request();
  }
  hostLost() {
    this.hostGeneration++;
    this.statusRequest = null;
    this.statusFollowup = false;
    this.devices.clear();
    this.lastTouch.clear();
    for (const identity of [...this.keys.keys()]) this.remove(identity);
    this.bridge.setActive(false);
    this.clock.reset();
    this.snapshot = idle();
  }
  stop() {
    this.hostLost();
    this.bridge.stop();
  }
};

// src/host.mjs
function repairHostTransport(plugin2, { onLost = () => {
}, onReady = () => {
} } = {}) {
  const transport = plugin2.transport;
  let stopped2 = false, retry = null, current = null;
  const clearPending = () => {
    for (const [id, call] of Object.entries(transport.pendingCalls)) {
      clearTimeout(call.timer);
      call.reject(new Error("FlexDesigner disconnected"));
      delete transport.pendingCalls[id];
    }
  };
  transport.start = () => {
    if (stopped2 || current) return;
    const ws = new wrapper_default(`ws://127.0.0.1:${transport.port}`);
    current = ws;
    transport.ws = ws;
    let lost = false;
    const lose = () => {
      if (lost || stopped2) return;
      lost = true;
      current = null;
      clearPending();
      onLost();
      if (!retry) retry = setTimeout(() => {
        retry = null;
        transport.start();
      }, 5e3);
    };
    ws.on("open", () => {
      transport._send("startup", { pluginID: transport.uuid });
      onReady();
    });
    ws.on("message", (bytes) => transport._handleMessage(bytes.toString()).catch(() => {
    }));
    ws.on("close", lose);
    ws.on("error", () => {
      ws.terminate();
      lose();
    });
  };
  return () => {
    stopped2 = true;
    clearTimeout(retry);
    retry = null;
    clearPending();
    current?.removeAllListeners();
    current?.terminate();
    current = null;
  };
}

// src/main.mjs
var application = new LyricsPlugin(plugin_client_default, { logger: logger_default });
var stopHost = repairHostTransport(plugin_client_default, { onLost: () => application.hostLost(), onReady: () => application.hostReady() });
var stopped = false;
var stop = () => {
  if (stopped) return;
  stopped = true;
  application.stop();
  stopHost();
  process.exit(0);
};
process.on("SIGTERM", stop);
process.on("SIGINT", stop);
plugin_client_default.start();
/*! Bundled license information:

safe-buffer/index.js:
  (*! safe-buffer. MIT License. Feross Aboukhadijeh <https://feross.org/opensource> *)

moment/moment.js:
  (*! moment.js *)
  (*! version : 2.31.0 *)
  (*! authors : Tim Wood, Iskren Chernev, Moment.js contributors *)
  (*! license : MIT *)
  (*! momentjs.com *)

file-stream-rotator/FileStreamRotator.js:
  (*!
   * FileStreamRotator
   * Copyright(c) 2012-2017 Holiday Extras.
   * Copyright(c) 2017 Roger C.
   * MIT Licensed
   *)
*/
