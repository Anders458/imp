#!/bin/bash
#
# Pluggable AI interface
# string in → string out
#

AI_PROVIDER="${IMP_AI_PROVIDER:-claude}"
AI_MODEL_FAST="${IMP_AI_MODEL_FAST:-haiku}"
AI_MODEL_SMART="${IMP_AI_MODEL_SMART:-sonnet}"

ai() {
   local prompt="$1"
   local model="${2:-$AI_MODEL_FAST}"

   case "$AI_PROVIDER" in
      claude)
         claude -p "$prompt" --model "$model" --max-turns 1 2> /dev/null
         ;;
      ollama)
         curl -s localhost:11434/api/generate \
            -d "$(jq -n --arg p "$prompt" --arg m "$model" \
               '{model:$m, prompt:$p, stream:false}')" \
            | jq -r '.response'
         ;;
      *)
         echo "Unknown AI provider: $AI_PROVIDER" >&2
         return 1
         ;;
   esac
}

ai_fast() {
   ai "$1" "$AI_MODEL_FAST"
}

ai_smart() {
   ai "$1" "$AI_MODEL_SMART"
}
