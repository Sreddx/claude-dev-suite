#!/bin/bash
# Generate session summary from trace log
TRACE_LOG=".claude/state/agent-trace.log"

if [ ! -f "$TRACE_LOG" ]; then
  echo "No trace log found — session had no tool calls"
  exit 0
fi

echo ""
echo "═══════════════════════════════════════"
echo "  SDD Session Report"
echo "═══════════════════════════════════════"
echo ""
echo "Tool calls: $(wc -l < "$TRACE_LOG")"
echo ""
echo "Tools used:"
grep -oP 'tool=\K\S+' "$TRACE_LOG" | sort | uniq -c | sort -rn | head -20
echo ""
echo "Timeline (first 10 / last 5):"
head -10 "$TRACE_LOG"
echo "..."
tail -5 "$TRACE_LOG"
echo ""
echo "═══════════════════════════════════════"

# Clean up for next session
mv "$TRACE_LOG" "$TRACE_LOG.$(date +%Y%m%d%H%M%S).bak" 2>/dev/null || true
