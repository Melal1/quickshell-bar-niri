.pragma library

function clamp(index, count) {
  if (count <= 0) return 0;
  if (index < 0) return 0;
  if (index >= count) return count - 1;
  return index;
}

function move(index, delta, count) {
  return clamp(index + delta, count);
}

function valid(index, count) {
  return index >= 0 && index < count;
}
