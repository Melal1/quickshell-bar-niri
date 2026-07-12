.pragma library

var NUMBER_BASE_TARGETS = [2, 8, 10, 16];

var UNIT_DEFS = [
  { key: "C", group: "temperature", aliases: ["c", "degc", "celsius"] },
  { key: "F", group: "temperature", aliases: ["f", "degf", "fahrenheit"] },
  { key: "K", group: "temperature", aliases: ["k", "kelvin"] },
  { key: "R", group: "temperature", aliases: ["r", "ra", "rankine"] },

  { key: "km", group: "length", factor: 1000, aliases: ["km", "kilometer", "kilometers"] },
  { key: "m", group: "length", factor: 1, aliases: ["m", "meter", "meters"] },
  { key: "cm", group: "length", factor: 0.01, aliases: ["cm", "centimeter", "centimeters"] },
  { key: "mm", group: "length", factor: 0.001, aliases: ["mm", "millimeter", "millimeters"] },
  { key: "um", group: "length", factor: 0.000001, aliases: ["um", "micrometer", "micrometers"] },
  { key: "nm", group: "length", factor: 0.000000001, aliases: ["nm", "nanometer", "nanometers"] },
  { key: "mi", group: "length", factor: 1609.344, aliases: ["mi", "mile", "miles"] },
  { key: "yd", group: "length", factor: 0.9144, aliases: ["yd", "yard", "yards"] },
  { key: "ft", group: "length", factor: 0.3048, aliases: ["ft", "foot", "feet"] },
  { key: "in", group: "length", factor: 0.0254, aliases: ["in", "inch", "inches"] },

  { key: "kg", group: "mass", factor: 1, aliases: ["kg", "kilogram", "kilograms"] },
  { key: "g", group: "mass", factor: 0.001, aliases: ["g", "gram", "grams"] },
  { key: "mg", group: "mass", factor: 0.000001, aliases: ["mg", "milligram", "milligrams"] },
  { key: "ug", group: "mass", factor: 0.000000001, aliases: ["ug", "microgram", "micrograms"] },
  { key: "t", group: "mass", factor: 1000, aliases: ["t", "tonne", "tonnes", "metricton"] },
  { key: "lb", group: "mass", factor: 0.45359237, aliases: ["lb", "lbs", "pound", "pounds"] },
  { key: "oz", group: "mass", factor: 0.028349523125, aliases: ["oz", "ounce", "ounces"] },

  { key: "L", group: "volume", factor: 1, aliases: ["l", "liter", "liters", "litre", "litres"] },
  { key: "mL", group: "volume", factor: 0.001, aliases: ["ml", "milliliter", "milliliters", "millilitre", "millilitres"] },
  { key: "m3", group: "volume", factor: 1000, aliases: ["m3", "cubicmeter", "cubicmeters"] },
  { key: "gal", group: "volume", factor: 3.785411784, aliases: ["gal", "gallon", "gallons"] },
  { key: "qt", group: "volume", factor: 0.946352946, aliases: ["qt", "quart", "quarts"] },
  { key: "pt", group: "volume", factor: 0.473176473, aliases: ["pt", "pint", "pints"] },
  { key: "cup", group: "volume", factor: 0.2365882365, aliases: ["cup", "cups"] },
  { key: "floz", group: "volume", factor: 0.0295735295625, aliases: ["floz", "fluidounce", "fluidounces"] },

  { key: "day", group: "time", factor: 86400, aliases: ["day", "days", "d"] },
  { key: "h", group: "time", factor: 3600, aliases: ["h", "hr", "hrs", "hour", "hours"] },
  { key: "min", group: "time", factor: 60, aliases: ["min", "mins", "minute", "minutes"] },
  { key: "s", group: "time", factor: 1, aliases: ["s", "sec", "secs", "second", "seconds"] },
  { key: "ms", group: "time", factor: 0.001, aliases: ["ms", "millisecond", "milliseconds"] },
  { key: "us", group: "time", factor: 0.000001, aliases: ["us", "microsecond", "microseconds"] },

  { key: "m/s", group: "speed", factor: 1, aliases: ["m/s", "mps", "meterpersecond", "meterspersecond"] },
  { key: "km/h", group: "speed", factor: 0.2777777777777778, aliases: ["km/h", "kph", "kmh", "kilometerperhour", "kilometersperhour"] },
  { key: "mph", group: "speed", factor: 0.44704, aliases: ["mph", "mileperhour", "milesperhour"] },
  { key: "kn", group: "speed", factor: 0.5144444444444445, aliases: ["kn", "knot", "knots"] },
  { key: "ft/s", group: "speed", factor: 0.3048, aliases: ["ft/s", "fps", "footpersecond", "feetpersecond"] },

  { key: "B", group: "data", factor: 1, aliases: ["b", "byte", "bytes"] },
  { key: "bit", group: "data", factor: 0.125, aliases: ["bit", "bits"] },
  { key: "KB", group: "data", factor: 1000, aliases: ["kb", "kilobyte", "kilobytes"] },
  { key: "MB", group: "data", factor: 1000000, aliases: ["mb", "megabyte", "megabytes"] },
  { key: "GB", group: "data", factor: 1000000000, aliases: ["gb", "gigabyte", "gigabytes"] },
  { key: "TB", group: "data", factor: 1000000000000, aliases: ["tb", "terabyte", "terabytes"] },
  { key: "KiB", group: "data", factor: 1024, aliases: ["kib", "kibyte", "kibibyte", "kibibytes"] },
  { key: "MiB", group: "data", factor: 1048576, aliases: ["mib", "mibyte", "mebibyte", "mebibytes"] },
  { key: "GiB", group: "data", factor: 1073741824, aliases: ["gib", "gibyte", "gibibyte", "gibibytes"] },
  { key: "TiB", group: "data", factor: 1099511627776, aliases: ["tib", "tibyte", "tebibyte", "tebibytes"] },

  { key: "rad", group: "angle", factor: 1, aliases: ["rad", "radian", "radians"] },
  { key: "deg", group: "angle", factor: Math.PI / 180, aliases: ["deg", "degree", "degrees"] },
  { key: "turn", group: "angle", factor: Math.PI * 2, aliases: ["turn", "turns"] },

  { key: "km2", group: "area", factor: 1000000, aliases: ["km2", "km^2", "squarekilometer", "squarekilometers"] },
  { key: "m2", group: "area", factor: 1, aliases: ["m2", "m^2", "squaremeter", "squaremeters"] },
  { key: "cm2", group: "area", factor: 0.0001, aliases: ["cm2", "cm^2", "squarecentimeter", "squarecentimeters"] },
  { key: "mm2", group: "area", factor: 0.000001, aliases: ["mm2", "mm^2", "squaremillimeter", "squaremillimeters"] },
  { key: "ft2", group: "area", factor: 0.09290304, aliases: ["ft2", "ft^2", "sqft", "squarefoot", "squarefeet"] },
  { key: "in2", group: "area", factor: 0.00064516, aliases: ["in2", "in^2", "sqin", "squareinch", "squareinches"] },
  { key: "acre", group: "area", factor: 4046.8564224, aliases: ["acre", "acres"] },
  { key: "ha", group: "area", factor: 10000, aliases: ["ha", "hectare", "hectares"] },

  { key: "J", group: "energy", factor: 1, aliases: ["j", "joule", "joules"] },
  { key: "kJ", group: "energy", factor: 1000, aliases: ["kj", "kilojoule", "kilojoules"] },
  { key: "cal", group: "energy", factor: 4.184, aliases: ["cal", "calorie", "calories"] },
  { key: "kcal", group: "energy", factor: 4184, aliases: ["kcal", "kilocalorie", "kilocalories"] },
  { key: "Wh", group: "energy", factor: 3600, aliases: ["wh", "watthour", "watthours"] },
  { key: "kWh", group: "energy", factor: 3600000, aliases: ["kwh", "kilowatthour", "kilowatthours"] },

  { key: "W", group: "power", factor: 1, aliases: ["w", "watt", "watts"] },
  { key: "kW", group: "power", factor: 1000, aliases: ["kw", "kilowatt", "kilowatts"] },
  { key: "hp", group: "power", factor: 745.6998715822702, aliases: ["hp", "horsepower"] },

  { key: "Pa", group: "pressure", factor: 1, aliases: ["pa", "pascal", "pascals"] },
  { key: "kPa", group: "pressure", factor: 1000, aliases: ["kpa", "kilopascal", "kilopascals"] },
  { key: "bar", group: "pressure", factor: 100000, aliases: ["bar", "bars"] },
  { key: "atm", group: "pressure", factor: 101325, aliases: ["atm", "atmosphere", "atmospheres"] },
  { key: "psi", group: "pressure", factor: 6894.757293168361, aliases: ["psi", "poundspersquareinch"] }
];

function evaluate(input) {
  var text = String(input || "").trim();
  if (text.length === 0) {
    return result(false, "Type an equation", "", "");
  }

  if (text.indexOf("->") !== -1) {
    return convert(text);
  }

  try {
    var parser = new Parser(text);
    var value = parser.parse();
    return result(true, formatNumber(value), "Enter copies result", formatNumber(value));
  } catch (e) {
    return result(false, e.message || String(e), "", "");
  }
}

function result(ok, display, detail, copy) {
  return {
    ok: ok,
    display: display,
    detail: detail,
    copy: copy
  };
}

function Parser(text) {
  this.text = text;
  this.pos = 0;
  this.current = null;
  this.next();
}

Parser.prototype.parse = function() {
  var value = this.expression();
  if (this.current.type !== "eof") {
    throw new Error("Unexpected '" + this.current.value + "'");
  }
  if (!isFinite(value)) {
    throw new Error("Result is not finite");
  }
  return value;
};

Parser.prototype.next = function() {
  this.skipSpaces();

  if (this.pos >= this.text.length) {
    this.current = { type: "eof", value: "" };
    return;
  }

  var ch = this.text.charAt(this.pos);
  if (isDigit(ch) || ch === ".") {
    this.current = this.readNumber();
    return;
  }

  if (isAlpha(ch)) {
    this.current = this.readIdentifier();
    return;
  }

  if ("+-*/%^(),".indexOf(ch) !== -1) {
    this.pos++;
    this.current = { type: ch, value: ch };
    return;
  }

  throw new Error("Unexpected '" + ch + "'");
};

Parser.prototype.skipSpaces = function() {
  while (this.pos < this.text.length && /\s/.test(this.text.charAt(this.pos))) {
    this.pos++;
  }
};

Parser.prototype.readNumber = function() {
  var start = this.pos;
  var seenDot = false;

  while (this.pos < this.text.length) {
    var ch = this.text.charAt(this.pos);
    if (isDigit(ch)) {
      this.pos++;
    } else if (ch === "." && !seenDot) {
      seenDot = true;
      this.pos++;
    } else {
      break;
    }
  }

  if (this.pos < this.text.length && /[eE]/.test(this.text.charAt(this.pos))) {
    this.pos++;
    if (this.pos < this.text.length && /[+-]/.test(this.text.charAt(this.pos))) {
      this.pos++;
    }
    while (this.pos < this.text.length && isDigit(this.text.charAt(this.pos))) {
      this.pos++;
    }
  }

  var raw = this.text.slice(start, this.pos);
  var value = Number(raw);
  if (!isFinite(value)) {
    throw new Error("Invalid number");
  }

  return { type: "number", value: value };
};

Parser.prototype.readIdentifier = function() {
  var start = this.pos;
  while (this.pos < this.text.length && isAlpha(this.text.charAt(this.pos))) {
    this.pos++;
  }
  return { type: "id", value: this.text.slice(start, this.pos).toLowerCase() };
};

Parser.prototype.expression = function() {
  return this.additive();
};

Parser.prototype.additive = function() {
  var value = this.multiplicative();
  while (this.current.type === "+" || this.current.type === "-") {
    var op = this.current.type;
    this.next();
    var right = this.multiplicative();
    value = op === "+" ? value + right : value - right;
  }
  return value;
};

Parser.prototype.multiplicative = function() {
  var value = this.power();
  while (this.current.type === "*" || this.current.type === "/" || this.current.type === "%") {
    var op = this.current.type;
    this.next();
    var right = this.power();
    if (op === "*") {
      value *= right;
    } else if (op === "/") {
      value /= right;
    } else {
      value %= right;
    }
  }
  return value;
};

Parser.prototype.power = function() {
  var value = this.unary();
  if (this.current.type === "^") {
    this.next();
    value = Math.pow(value, this.power());
  }
  return value;
};

Parser.prototype.unary = function() {
  if (this.current.type === "+") {
    this.next();
    return this.unary();
  }

  if (this.current.type === "-") {
    this.next();
    return -this.unary();
  }

  if (this.current.type === "id" && (this.current.value === "d" || this.current.value === "deg")) {
    this.next();
    return this.unary() * Math.PI / 180;
  }

  return this.primary();
};

Parser.prototype.primary = function() {
  if (this.current.type === "number") {
    var value = this.current.value;
    this.next();
    return value;
  }

  if (this.current.type === "(") {
    this.next();
    var grouped = this.expression();
    this.expect(")");
    return grouped;
  }

  if (this.current.type === "id") {
    var name = this.current.value;
    this.next();

    if (this.current.type === "(") {
      this.next();
      var arg = this.expression();
      this.expect(")");
      return applyFunction(name, arg);
    }

    if (name === "pi") return Math.PI;
    if (name === "e") return Math.E;
    if (name === "tau") return Math.PI * 2;

    throw new Error("Unknown name '" + name + "'");
  }

  throw new Error("Expected a number");
};

Parser.prototype.expect = function(type) {
  if (this.current.type !== type) {
    throw new Error("Expected '" + type + "'");
  }
  this.next();
};

function applyFunction(name, value) {
  if (name === "sqrt") return Math.sqrt(value);
  if (name === "sin") return Math.sin(value);
  if (name === "cos") return Math.cos(value);
  if (name === "tan") return Math.tan(value);
  if (name === "asin") return Math.asin(value);
  if (name === "acos") return Math.acos(value);
  if (name === "atan") return Math.atan(value);
  if (name === "ln") return Math.log(value);
  if (name === "log") return Math.log(value) / Math.LN10;
  if (name === "exp") return Math.exp(value);
  if (name === "abs") return Math.abs(value);
  if (name === "floor") return Math.floor(value);
  if (name === "ceil") return Math.ceil(value);
  if (name === "round") return Math.round(value);

  throw new Error("Unknown function '" + name + "'");
}

function convert(text) {
  var parts = text.split("->");
  if (parts.length !== 2) {
    return result(false, "Use one -> conversion", "", "");
  }

  var numberBase = parseNumberBase(parts[0]);
  if (numberBase.ok) {
    return convertNumberBase(numberBase, parts[1]);
  }
  if (numberBase.error) {
    return result(false, numberBase.error, "", "");
  }

  return convertUnit(parts[0], parts[1]);
}

function convertUnit(left, right) {
  var quantity = parseUnitQuantity(left);
  if (!quantity.ok) {
    return result(false, quantity.error, "", "");
  }

  var targets = parseUnitTargets(right, quantity.unit);
  if (!targets.ok) {
    return result(false, targets.error, "", "");
  }

  var baseValue;
  if (quantity.unit.group === "temperature") {
    baseValue = toKelvin(quantity.value, quantity.unit.key);
    if (baseValue < 0) {
      return result(false, "Temperature is below absolute zero", "", "");
    }
  } else {
    baseValue = quantity.value * quantity.unit.factor;
  }

  var out = [];
  for (var i = 0; i < targets.units.length; i++) {
    var target = targets.units[i];
    var converted = target.group === "temperature"
      ? fromKelvin(baseValue, target.key)
      : baseValue / target.factor;
    out.push(formatNumber(converted) + " " + target.key);
  }

  var display = out.join("  |  ");
  return result(true, display, formatNumber(quantity.value) + " " + quantity.unit.key + " -> " + targets.label, display);
}

function parseUnitQuantity(text) {
  var match = String(text || "").trim().match(/^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*([a-zA-Z0-9\/\^]+)$/);
  if (!match) {
    return { ok: false, error: "Use value+unit or (value)base" };
  }

  var unit = findUnit(match[2]);
  if (!unit) {
    return { ok: false, error: "Unknown unit '" + match[2] + "'" };
  }

  return { ok: true, value: Number(match[1]), unit: unit };
}

function parseUnitTargets(text, sourceUnit) {
  var raw = String(text || "").trim();
  if (raw.length === 0) {
    return { ok: false, error: "Type target unit or all" };
  }
  if (raw.toLowerCase() === "all") {
    return { ok: true, units: unitsInGroup(sourceUnit.group, sourceUnit.key), label: "all" };
  }

  var chunks = raw.split(/[\s,]+/);
  var units = [];
  for (var i = 0; i < chunks.length; i++) {
    if (chunks[i].length === 0) continue;
    var unit = findUnit(chunks[i]);
    if (!unit) {
      return { ok: false, error: "Unknown unit '" + chunks[i] + "'" };
    }
    if (unit.group !== sourceUnit.group) {
      return { ok: false, error: "Cannot convert " + sourceUnit.key + " to " + unit.key };
    }
    if (!containsUnit(units, unit.key)) {
      units.push(unit);
    }
  }

  if (units.length === 0) {
    units = unitsInGroup(sourceUnit.group, sourceUnit.key);
  }

  return { ok: true, units: units, label: raw };
}

function unitsInGroup(group, sourceKey) {
  var units = [];
  for (var i = 0; i < UNIT_DEFS.length; i++) {
    if (UNIT_DEFS[i].group === group && UNIT_DEFS[i].key !== sourceKey) {
      units.push(UNIT_DEFS[i]);
    }
  }
  return units;
}

function findUnit(unit) {
  var clean = normalizeUnitName(unit);
  for (var i = 0; i < UNIT_DEFS.length; i++) {
    var aliases = UNIT_DEFS[i].aliases;
    for (var j = 0; j < aliases.length; j++) {
      if (normalizeUnitName(aliases[j]) === clean) {
        return UNIT_DEFS[i];
      }
    }
  }
  return null;
}

function normalizeUnitName(unit) {
  return String(unit || "").replace(/[\s_\-]/g, "").toLowerCase();
}

function containsUnit(units, key) {
  for (var i = 0; i < units.length; i++) {
    if (units[i].key === key) return true;
  }
  return false;
}

function toKelvin(value, unit) {
  if (unit === "C") return value + 273.15;
  if (unit === "F") return (value - 32) * 5 / 9 + 273.15;
  if (unit === "K") return value;
  if (unit === "R") return value * 5 / 9;
  return NaN;
}

function fromKelvin(value, unit) {
  if (unit === "C") return value - 273.15;
  if (unit === "F") return (value - 273.15) * 9 / 5 + 32;
  if (unit === "K") return value;
  if (unit === "R") return value * 9 / 5;
  return NaN;
}

function parseNumberBase(text) {
  var match = String(text || "").trim().match(/^\(\s*([+-]?[0-9a-zA-Z]+)\s*\)\s*([0-9]+)$/);
  if (!match) {
    return { ok: false };
  }

  var base = Number(match[2]);
  if (Math.floor(base) !== base || base < 2 || base > 36) {
    return { ok: false, error: "Base must be 2-36" };
  }

  var value = parseInt(match[1], base);
  if (!isFinite(value) || !validForBase(match[1], base)) {
    return { ok: false, error: "Invalid base-" + base + " number" };
  }

  return { ok: true, raw: match[1], base: base, value: value };
}

function validForBase(raw, base) {
  var text = String(raw || "").replace(/^[+-]/, "").toLowerCase();
  if (text.length === 0) return false;

  for (var i = 0; i < text.length; i++) {
    var digit = parseInt(text.charAt(i), 36);
    if (!isFinite(digit) || digit >= base) {
      return false;
    }
  }

  return true;
}

function convertNumberBase(source, right) {
  if (source.error) {
    return result(false, source.error, "", "");
  }

  var targets = parseBaseTargets(right, source.base);
  if (!targets.ok) {
    return result(false, targets.error, "", "");
  }

  var out = [];
  for (var i = 0; i < targets.bases.length; i++) {
    var base = targets.bases[i];
    out.push("(" + source.value.toString(base).toUpperCase() + ")" + base);
  }

  var display = out.join("  |  ");
  return result(true, display, "(" + source.raw + ")" + source.base + " -> " + targets.label, display);
}

function parseBaseTargets(text, sourceBase) {
  var raw = String(text || "").trim();
  if (raw.length === 0) {
    return { ok: false, error: "Type target base or all" };
  }
  if (raw.toLowerCase() === "all") {
    var all = [];
    for (var i = 0; i < NUMBER_BASE_TARGETS.length; i++) {
      if (NUMBER_BASE_TARGETS[i] !== sourceBase) {
        all.push(NUMBER_BASE_TARGETS[i]);
      }
    }
    return { ok: true, bases: all, label: "all" };
  }

  var chunks = raw.split(/[\s,]+/);
  var bases = [];
  for (var j = 0; j < chunks.length; j++) {
    if (chunks[j].length === 0) continue;
    var base = Number(chunks[j]);
    if (String(base) !== chunks[j] || Math.floor(base) !== base || base < 2 || base > 36) {
      return { ok: false, error: "Base must be 2-36" };
    }
    if (bases.indexOf(base) === -1) {
      bases.push(base);
    }
  }

  return { ok: true, bases: bases, label: raw };
}

function formatNumber(value) {
  if (!isFinite(value)) {
    return "NaN";
  }

  var clean = Math.abs(value) < 1e-12 ? 0 : value;
  return Number(clean.toPrecision(12)).toString();
}

function isDigit(ch) {
  return ch >= "0" && ch <= "9";
}

function isAlpha(ch) {
  return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z");
}
