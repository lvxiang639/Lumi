import json
import re


def parse_json(raw: str) -> dict:
    """Extract JSON from an LLM response, with fallbacks.

    Tries: direct parse → markdown code fence → regex extraction.
    """
    raw = raw.strip() if raw else ""
    if not raw:
        return {}

    # Direct parse
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass

    # Extract from markdown code fence
    if "```" in raw:
        lines = raw.split("\n")
        inside = False
        parts = []
        for line in lines:
            if "```" in line:
                if inside:
                    break
                inside = True
                continue
            if inside:
                parts.append(line)
        if parts:
            try:
                return json.loads("\n".join(parts))
            except json.JSONDecodeError:
                pass

    # Regex extraction of JSON object
    match = re.search(r'\{[^{}]*\}', raw)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass

    return {}
