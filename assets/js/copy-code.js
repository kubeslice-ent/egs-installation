// Copy code functionality for GitHub Pages
document.addEventListener('DOMContentLoaded', function() {
    // Find all code blocks and wrap them with copy functionality
    const codeBlocks = document.querySelectorAll('pre');
    
    codeBlocks.forEach(function(codeBlock, index) {
        // Create wrapper container
        const container = document.createElement('div');
        container.className = 'code-container';
        
        // Create copy button
        const copyButton = document.createElement('button');
        copyButton.className = 'copy-button';
        copyButton.setAttribute('aria-label', 'Copy code to clipboard');
        copyButton.setAttribute('title', 'Copy code to clipboard');
        
        // Insert wrapper before code block
        codeBlock.parentNode.insertBefore(container, codeBlock);
        
        // Move code block into wrapper and add copy button
        container.appendChild(codeBlock);
        container.appendChild(copyButton);
        
        // Add click event to copy button
        copyButton.addEventListener('click', function() {
            // Get the code content
            const code = codeBlock.querySelector('code');
            const textContent = code ? code.textContent : codeBlock.textContent;
            
            // Copy to clipboard
            navigator.clipboard.writeText(textContent).then(function() {
                // Show success feedback
                copyButton.classList.add('copied');
                
                // Reset button after 2 seconds
                setTimeout(function() {
                    copyButton.classList.remove('copied');
                }, 2000);
            }).catch(function(err) {
                // Fallback for older browsers
                const textArea = document.createElement('textarea');
                textArea.value = textContent;
                textArea.style.position = 'fixed';
                textArea.style.left = '-999999px';
                textArea.style.top = '-999999px';
                document.body.appendChild(textArea);
                textArea.focus();
                textArea.select();
                
                try {
                    document.execCommand('copy');
                    copyButton.classList.add('copied');
                    setTimeout(function() {
                        copyButton.classList.remove('copied');
                    }, 2000);
                } catch (err) {
                    console.error('Failed to copy code: ', err);
                }
                
                document.body.removeChild(textArea);
            });
        });
    });
});

// Add keyboard support for copy buttons
document.addEventListener('keydown', function(e) {
    if (e.key === 'Enter' || e.key === ' ') {
        if (e.target.classList.contains('copy-button')) {
            e.preventDefault();
            e.target.click();
        }
    }
});
