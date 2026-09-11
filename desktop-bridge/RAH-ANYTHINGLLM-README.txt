RAH + AnythingLLM integration notes
==================================

1. AnythingLLM Desktop can be installed/updated with:
   winget install -e --id MintplexLabs.AnythingLLM --source winget

2. For Raven integration, create a Developer API key inside AnythingLLM:
   Settings > Developer API > Generate New API Key

3. Store the key locally only at:
   C:\RAH\State\AnythingLLM\API-TOKEN.txt

4. Do not commit or upload this token.

5. Recommended model provider for the existing Raven setup:
   LM Studio, if its local server is already running and stable.

6. AnythingLLM is treated as an optional knowledge/agent layer.
   Raven core and Raven Workers must remain able to run if AnythingLLM is offline.
