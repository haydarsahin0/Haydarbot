"""
Comment generation module – produces relevant replies for AI/tech tweets.

When an OpenAI API key is present, a GPT model generates a contextual comment.
Otherwise a random template from config.py is used as a fallback.
"""

import logging
import random
from typing import Optional

from config import COMMENT_TEMPLATES, OPENAI_MODEL, OPENAI_SYSTEM_PROMPT

logger = logging.getLogger(__name__)


def generate_comment(tweet_text: str, openai_api_key: Optional[str] = None) -> str:
    """Generate a comment for the given tweet text.

    Tries OpenAI first (if *openai_api_key* is provided), then falls back to a
    random template from :data:`config.COMMENT_TEMPLATES`.

    Parameters
    ----------
    tweet_text:
        The full text of the tweet to reply to.
    openai_api_key:
        Optional OpenAI API key.  When ``None`` or empty the AI path is skipped.

    Returns
    -------
    str
        A non-empty comment string.
    """
    if openai_api_key:
        comment = _generate_with_openai(tweet_text, openai_api_key)
        if comment:
            return comment

    return _random_template()


def _generate_with_openai(tweet_text: str, api_key: str) -> Optional[str]:
    """Call OpenAI Chat Completions and return the generated comment, or None on error."""
    try:
        from openai import OpenAI  # local import keeps the module importable without openai installed
        import openai as _openai

        client = OpenAI(api_key=api_key)
        response = client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {"role": "system", "content": OPENAI_SYSTEM_PROMPT},
                {"role": "user", "content": f"Tweet: {tweet_text}"},
            ],
            max_tokens=100,
            temperature=0.8,
        )
        comment = response.choices[0].message.content.strip()
        if comment:
            logger.debug("OpenAI comment generated successfully.")
            return comment
    except (_openai.OpenAIError, ImportError) as exc:
        logger.warning("OpenAI comment generation failed: %s. Using template.", exc)

    return None


def _random_template() -> str:
    """Return a random comment template."""
    return random.choice(COMMENT_TEMPLATES)
