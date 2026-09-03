BEGIN {
  print "return {"
  print "  exact = {"
  prefix_count = 0
  default_icon = ""
}

/^[[:space:]]*"[^"]*"\)[[:space:]]*icon_result=/ {
  line = $0
  sub(/^[[:space:]]*"/, "", line)
  key = line
  sub(/"\).*$/, "", key)
  val = line
  sub(/^[^)]*\)[[:space:]]*icon_result="/, "", val)
  sub(/"[[:space:]]*;;[[:space:]]*$/, "", val)
  gsub(/\\/, "\\\\", key)
  printf "    [\"%s\"] = \"%s\",\n", key, val
  pat_n = 0
  next
}

/^[[:space:]]*icon_result=/ {
  line = $0
  sub(/^[[:space:]]*icon_result="/, "", line)
  sub(/"[[:space:]]*$/, "", line)
  icon = line

  if (pending_default) {
    default_icon = icon
    pending_default = 0
    pat_n = 0
    next
  }

  for (i = 1; i <= pat_n; i++) {
    p = pats[i]
    if (is_prefix[i]) {
      prefix_count++
      prefix_pat[prefix_count] = p
      prefix_icon[prefix_count] = icon
    } else {
      gsub(/\\/, "\\\\", p)
      printf "    [\"%s\"] = \"%s\",\n", p, icon
    }
  }
  pat_n = 0
  next
}

/^[[:space:]]*\*\)[[:space:]]*$/ {
  pending_default = 1
  pat_n = 0
  next
}

/\)[[:space:]]*$/ {
  line = $0
  sub(/[[:space:]]*\)[[:space:]]*$/, "", line)
  sub(/^[[:space:]]*/, "", line)

  pat_n = 0
  n = split(line, parts, /[[:space:]]*\|[[:space:]]*/)
  for (i = 1; i <= n; i++) {
    p = parts[i]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", p)
    star = 0
    if (p ~ /\*$/) {
      star = 1
      sub(/\*$/, "", p)
    }
    if (p ~ /^".*"$/) {
      sub(/^"/, "", p)
      sub(/"$/, "", p)
      pat_n++
      pats[pat_n] = p
      is_prefix[pat_n] = star
    }
  }
  next
}

END {
  print "  },"
  print "  prefix = {"
  for (i = 1; i <= prefix_count; i++) {
    p = prefix_pat[i]
    gsub(/\\/, "\\\\", p)
    printf "    { \"%s\", \"%s\" },\n", p, prefix_icon[i]
  }
  print "  },"
  printf "  default = \"%s\",\n", default_icon
  print "}"
}
