import { CONTRACT_ADDRESSES } from './contracts-config.js';
import { ROULETTE_ABI } from './abi/roulette-abi.js';
import { ACCOUNT_MANAGER_ABI } from './abi/account-manager-abi.js';

class RouletteGame {
    constructor() {
        this.provider = null;
        this.signer = null;
        this.rouletteContract = null;
        this.accountManagerContract = null;
        this.spinSound = new Audio('assets/wheel-spin.mp3');
        this.spinSound.volume = 0.3; // Lower volume for this specific sound
        this.spinDuration = 5000; // 5 seconds for the full spin animation
        
        // Add background music
        this.backgroundMusic = new Audio('assets/background.mp3');
        this.backgroundMusic.volume = 0.3; // Increased from 0.1 to 0.3
        this.backgroundMusic.loop = true; // Enable looping
        this.backgroundMusic.currentTime = 15; // Start from 15 seconds
        
        this.initialize();
        this.setupBackgroundMusic();
    }

    async initialize() {
        try {
            // Khởi tạo kết nối Hardhat ngay lập tức
            const hardhatProvider = new window.ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
            
            // Verify network
            const network = await hardhatProvider.getNetwork();
            console.log("Connected to network:", network);
            if (network.chainId !== 31337) {
                throw new Error("Please connect to Hardhat network");
            }

            const defaultWallet = new window.ethers.Wallet(
                "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
                hardhatProvider
            );

            this.provider = hardhatProvider;
            this.signer = defaultWallet;
            
            // Verify contracts before proceeding
            await this.verifyContracts();
            
            this.setupEventListeners();
            await this.autoConnectHardhatAccount();
            console.log("Application initialized with Hardhat account");
        } catch (err) {
            console.error("Failed to initialize:", err);
            alert("Failed to connect to Hardhat node. Please make sure it's running and contracts are deployed");
        }
    }

    async verifyContracts() {
        // Verify contract addresses exist
        if (!CONTRACT_ADDRESSES.accountManager || !CONTRACT_ADDRESSES.roulette) {
            throw new Error("Contract addresses not configured");
        }

        // Verify contracts are deployed
        const accountManagerCode = await this.provider.getCode(CONTRACT_ADDRESSES.accountManager);
        const rouletteCode = await this.provider.getCode(CONTRACT_ADDRESSES.roulette);

        if (accountManagerCode === '0x' || rouletteCode === '0x') {
            throw new Error("Contracts not deployed. Please run deployment script first");
        }

        console.log("Contracts verified successfully");
    }

    async autoConnectHardhatAccount() {
        try {
            const address = await this.signer.getAddress();
            
            // Hiển thị địa chỉ ví và cập nhật UI
            const walletInfo = document.getElementById('wallet-info');
            const walletAddress = document.getElementById('walletAddress');
            const connectBtn = document.getElementById('connectWallet');
            
            walletAddress.textContent = `${address.slice(0,6)}...${address.slice(-4)} (Hardhat)`;
            walletInfo.classList.remove('d-none');
            connectBtn.classList.add('d-none');
            walletInfo.classList.add('connected');

            // Kiểm tra kết nối Hardhat node
            const network = await this.provider.getNetwork();
            console.log("Connected to network:", network);
            
            // Setup contracts trước khi kích hoạt tài khoản
            await this.setupContracts();
            
            // Kiểm tra và kích hoạt tài khoản
            await this.ensureAccountActive();
            
            this.updateUIState('connected');
            await this.updateWalletBalance();
            
            console.log('Connected to Hardhat account:', address);
        } catch (err) {
            console.error("Failed to connect Hardhat account:", err);
            alert("Error connecting to Hardhat node. Make sure it's running with: npm run node");
        }
    }

    async ensureAccountActive() {
        try {
            if (!this.accountManagerContract) {
                throw new Error("Contract not initialized");
            }

            const address = await this.signer.getAddress();
            console.log("Checking account activation for address:", address);
            
            // Pass the address to getAccountInfo
            const accountInfo = await this.accountManagerContract.getAccountInfo(address);
            console.log("Account info:", accountInfo);
            
            if (!accountInfo.isActive) {
                console.log("Account not active, activating...");
                const tx = await this.accountManagerContract.activateAccount();
                await tx.wait();
                console.log("Account activation transaction completed");
            } else {
                console.log("Account already active");
            }
        } catch (error) {
            console.error("Error during account activation:", error);
            throw error;
        }
    }

    setupEventListeners() {
        const connectBtn = document.getElementById('connectWallet');
        const placeBetBtn = document.getElementById('placeBet');
        const switchWalletBtn = document.getElementById('switchWallet');
        const depositBtn = document.getElementById('deposit');
        const withdrawBtn = document.getElementById('withdraw');
        
        connectBtn.addEventListener('click', () => this.connectWallet());
        placeBetBtn.addEventListener('click', () => this.placeBet());
        switchWalletBtn.addEventListener('click', () => this.switchWallet());
        depositBtn.addEventListener('click', () => this.showDepositDialog());
        withdrawBtn.addEventListener('click', () => this.showWithdrawDialog());
    }

    updateUIState(state) {
        const loading = document.getElementById('loading');
        const statusMessage = document.getElementById('status-message');
        const placeBetBtn = document.getElementById('placeBet');

        switch(state) {
            case 'disconnected':
                placeBetBtn.disabled = true;
                statusMessage.textContent = 'Please connect your wallet';
                break;
            case 'connected':
                placeBetBtn.disabled = false;
                statusMessage.textContent = 'Ready to play';
                break;
            case 'processing':
                loading.classList.remove('hidden');
                placeBetBtn.disabled = true;
                break;
            case 'completed':
                loading.classList.add('hidden');
                placeBetBtn.disabled = false;
                break;
        }
    }

    async connectWallet() {
        try {
            // Always try to connect to MetaMask first
            if (window.ethereum) {
                await this.switchWallet();
            } else {
                throw new Error("MetaMask not installed");
            }
        } catch (err) {
            console.error("Failed to connect wallet:", err);
            alert("Failed to connect MetaMask, using Hardhat account");
            await this.autoConnectHardhatAccount();
        }
    }

    async switchWallet() {
        try {
            // Reset UI state
            document.getElementById('wallet-info').classList.add('d-none');
            document.getElementById('connectWallet').classList.remove('d-none');
            
            // Switch to MetaMask provider
            if (window.ethereum) {
                this.provider = new window.ethers.providers.Web3Provider(window.ethereum);
                await window.ethereum.request({
                    method: 'wallet_requestPermissions',
                    params: [{ eth_accounts: {} }]
                });
                
                // Get MetaMask signer
                this.signer = this.provider.getSigner();
                const address = await this.signer.getAddress();
                
                // Update UI with MetaMask account
                const walletInfo = document.getElementById('wallet-info');
                const walletAddress = document.getElementById('walletAddress');
                
                walletAddress.textContent = `${address.slice(0,6)}...${address.slice(-4)} (MetaMask)`;
                walletInfo.classList.remove('d-none');
                document.getElementById('connectWallet').classList.add('d-none');
                walletInfo.classList.add('connected');
                
                // Setup contracts with new signer
                await this.setupContracts();
                await this.ensureAccountActive();
                this.updateUIState('connected');
                await this.updateWalletBalance();
                
                console.log('Switched to MetaMask account:', address);
            } else {
                throw new Error("MetaMask not installed");
            }
        } catch (err) {
            console.error("Failed to switch wallet:", err);
            alert("Failed to switch to MetaMask: " + err.message);
            
            // Fallback to Hardhat account if switch fails
            await this.autoConnectHardhatAccount();
        }
    }

    async setupContracts() {
        try {
            if (!this.signer) {
                throw new Error("No signer available");
            }

            // Verify contract addresses
            await this.verifyContracts();

            this.rouletteContract = new window.ethers.Contract(
                CONTRACT_ADDRESSES.roulette,
                ROULETTE_ABI,
                this.signer
            );

            this.accountManagerContract = new window.ethers.Contract(
                CONTRACT_ADDRESSES.accountManager,
                ACCOUNT_MANAGER_ABI,
                this.signer
            );

            console.log("Contracts setup completed");
        } catch (error) {
            console.error("Error setting up contracts:", error);
            throw error;
        }
    }

    prepareBetChoices() {
        let choices;
        if (this.selectedNumber !== undefined) {
            choices = [this.selectedNumber]; // Single number bet
            this.lastBetType = 'single';
            console.log("Preparing single number bet:", this.selectedNumber);
        } else if (this.selectedBetType) {
            this.lastBetType = this.selectedBetType;
            console.log("Preparing special bet:", this.selectedBetType);
            switch(this.selectedBetType) {
                case 'red':
                    choices = [37]; // Red
                    break;
                case 'black':
                    choices = [38]; // Black
                    break;
                case 'even':
                    choices = [39]; // Even
                    console.log("Selected even bet");
                    break;
                case 'odd':
                    choices = [40]; // Odd
                    console.log("Selected odd bet");
                    break;
                case '1-18':
                    choices = [41]; // Low numbers
                    break;
                case '19-36':
                    choices = [42]; // High numbers
                    break;
                case '1st12':
                    choices = [43]; // 1st dozen (1-12)
                    console.log("Selected 1st dozen bet");
                    break;
                case '2nd12':
                    choices = [44]; // 2nd dozen (13-24)
                    console.log("Selected 2nd dozen bet");
                    break;
                case '3rd12':
                    choices = [45]; // 3rd dozen (25-36)
                    console.log("Selected 3rd dozen bet");
                    break;
                default:
                    throw new Error("Invalid bet type");
            }
        }
        
        console.log("Bet preparation:", {
            type: this.lastBetType,
            choices: choices,
            selectedNumber: this.selectedNumber,
            selectedBetType: this.selectedBetType
        });
        
        console.log("Final bet choices:", choices);
        return choices;
    }

    async placeBet() {
        try {
            if (!this.selectedNumber && !this.selectedBetType) {
                alert('Please select a number or betting type');
                return;
            }
            
            let betAmount = document.getElementById('betAmount').value;
            if (!betAmount) {
                alert('Please enter a bet amount');
                return;
            }

            this.updateUIState('processing');
            
            // Start spinning animation
            const wheel = document.getElementById('wheel');
            wheel.style.transition = `transform ${this.spinDuration/1000}s cubic-bezier(0.32, 0.64, 0.45, 1)`;
            wheel.style.transform = 'rotate(1440deg)'; // 4 full rotations for longer spin

            // Play spinning sound
            this.spinSound.currentTime = 0;
            await this.spinSound.play();

            // Lower background music volume during spin
            const originalVolume = this.backgroundMusic.volume;
            this.backgroundMusic.volume = 0.5; // Increased from 0.05 to 0.15 during spin

            // Chuyển đổi số tiền sang định dạng hợp lệ
            const cleanBetAmount = betAmount.replace(',', '.');
            let betAmountWei;
            try {
                // Remove any commas and ensure proper decimal format
                betAmount = betAmount.replace(/,/g, '').trim();
                // Validate if it's a proper number
                if (!/^\d*\.?\d*$/.test(betAmount)) {
                    throw new Error('Invalid number format');
                }
                betAmountWei = ethers.utils.parseUnits(betAmount, 'ether');
            } catch (error) {
                alert('Invalid bet amount. Please enter a valid number.');
                return;
            }
            
            // Prepare choices array
            let choices = this.prepareBetChoices();
            
            console.log("Placing bet and spinning:", {
                choices: choices,
                amount: betAmountWei.toString()
            });

            // Log bet details before sending
            console.log("Placing bet:", {
                selectedNumber: this.selectedNumber,
                selectedBetType: this.selectedBetType,
                betAmount: betAmount
            });

            // Kiểm tra số dư trước khi đặt cược
            const balance = await this.getPlayerBalance();
            if (balance.lt(betAmountWei)) {
                alert('Insufficient balance. Please deposit more funds.');
                return;
            }

            // Gọi hàm trên contract và đợi transaction
            const tx = await this.rouletteContract.placeBetAndSpin(choices, { 
                value: betAmountWei,
                gasLimit: 500000
            });
            
            console.log("Transaction sent:", tx.hash);

            // Đợi transaction hoàn thành
            const receipt = await tx.wait();
            
            // Log all events from receipt
            console.log("Transaction events:", receipt);
            
            if (receipt.events) {
                receipt.events.forEach(event => {
                    // Check if event has args property
                    if (!event.args) return;
                    
                    switch(event.event) {
                        case 'GameResult':
                            const { result, betAmount, winAmount, isWin } = event.args;
                            console.log('Game Result:', {
                                result: parseInt(result),
                                betAmount: betAmount.toString(),
                                winAmount: winAmount.toString(),
                                isWin
                            });
                            break;
                            
                        case 'Debug':
                            if (event.args.message && event.args.value) {
                                console.log(`Debug: ${event.args.message} = ${event.args.value.toString()}`);
                            }
                            break;
                            
                        case 'BetPlaced':
                            console.log('Bet Placed:', event.args);
                            break;
                            
                        case 'SpinResult':
                            console.log('Spin Result:', event.args);
                            break;
                            
                        default:
                            console.log(`Event ${event.event}:`, event.args);
                    }
                });
            }

            // Update balance after bet
            await this.updateWalletBalance();

            // Process game result
            const gameResultEvent = receipt.events?.find(e => e.event === 'GameResult');
            if (gameResultEvent) {
                const { result, winAmount, isWin } = gameResultEvent.args;
                const resultNumber = parseInt(result);

                // Wait for the longer spin animation and sound
                await Promise.all([
                    new Promise(resolve => setTimeout(resolve, this.spinDuration)),
                    new Promise(resolve => {
                        this.spinSound.onended = resolve;
                    })
                ]);
                
                // Fade out the sound
                const fadeOut = setInterval(() => {
                    if (this.spinSound.volume > 0.02) {
                        this.spinSound.volume -= 0.02;
                    } else {
                        clearInterval(fadeOut);
                        this.spinSound.pause();
                        this.spinSound.volume = 0.3; // Reset volume
                        this.spinSound.currentTime = 0;
                    }
                }, 50);

                // Reset and show final position
                wheel.style.transition = 'none';
                wheel.style.transform = 'rotate(0deg)';
                wheel.offsetHeight;
                wheel.style.transition = 'transform 1.5s ease-out';
                wheel.style.transform = `rotate(${resultNumber * 10}deg)`;

                // Update UI with result
                const resultDisplay = document.getElementById('result');
                resultDisplay.textContent = `Result: ${resultNumber}`;
                resultDisplay.className = `result-display ${isWin ? 'win' : 'lose'}`;

                // Show detailed result message
                if (isWin) {
                    const winAmountEth = ethers.utils.formatUnits(winAmount, 'ether');
                    alert(`Congratulations! You bet ${betAmount} ETH and won ${winAmountEth} ETH!`);
                } else {
                    alert(`Sorry, you lost ${betAmount} ETH. Better luck next time!`);
                }

                // Update wallet balance
                await this.updateWalletBalance();

                // Restore background music volume after spin
                setTimeout(() => {
                    this.backgroundMusic.volume = originalVolume;
                }, this.spinDuration + 1000);
            }

            // Reset UI
            this.resetUI();
            // Lưu bet vào MongoDB
            const { result, winAmount, isWin } = gameResultEvent.args;
            const resultNumber = parseInt(result);
            const betData = {
                player: this.signer.address,
                amount: parseFloat(cleanBetAmount),
                betType: this.selectedBetType,  
                result: resultNumber,
                win: isWin
            };
            try {
                const response = await fetch('/api/bets', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(betData)
                });
                
                if (!response.ok) {
                    throw new Error('Failed to save bet data');
                }
            } catch (error) {
                console.error('Error saving bet:', error);
            }
            
        } catch (error) {
            // Stop and reset sound if there's an error
            this.spinSound.pause();
            this.spinSound.currentTime = 0;
            this.spinSound.volume = 0.3;
            console.error('Detailed error:', error);
            alert('Error placing bet: ' + error.message);
            this.updateUIState('connected');

            // Restore background music volume on error
            this.backgroundMusic.volume = 0.3;
        }
    }

    resetUI() {
        this.selectedNumber = undefined;
        this.selectedBetType = undefined;
        document.getElementById('betAmount').value = '';
        document.querySelectorAll('.number-cell').forEach(cell => cell.classList.remove('selected'));
        document.querySelectorAll('.btn-betting').forEach(btn => btn.classList.remove('active'));
        this.updateUIState('completed');
    }

    // Cập nhật hàm getCurrentBetId
    async getCurrentBetId() {
        try {
            const betCounter = await this.rouletteContract.getbetCounter();
            // Đảm bảo rằng chúng ta có một bet ID hợp lệ
            return betCounter.gt(0) ? betCounter.sub(1) : ethers.BigNumber.from(0);
        } catch (error) {
            console.error('Error getting current bet ID:', error);
            throw error;
        }
    }

    async showDepositDialog() {
        try {
            const address = await this.signer.getAddress();
            const accountInfo = await this.accountManagerContract.getAccountInfo(address);
            
            if (!accountInfo.isActive) {
                const tx = await this.accountManagerContract.activateAccount();
                await tx.wait();
            }

            const amount = prompt('Enter amount to deposit (ETH):');
            if (amount) {
                const amountInWei = window.ethers.utils.parseEther(amount);
                const tx = await this.accountManagerContract.deposit({ value: amountInWei });
                await tx.wait();
                await this.updateWalletBalance();
                alert('Deposit successful!');
            }
        } catch (error) {
            console.error('Deposit failed:', error);
            alert('Deposit failed: ' + error.message);
        }
    }

    async showWithdrawDialog() {
        const amount = prompt('Enter amount to withdraw (ETH):');
        if (amount) {
            try {
                const amountInWei = window.ethers.utils.parseEther(amount);
                const tx = await this.accountManagerContract.withdraw(amountInWei);
                await tx.wait();
                await this.updateWalletBalance();
                alert('Withdrawal successful!');
            } catch (error) {
                console.error('Withdrawal failed:', error);
                alert('Withdrawal failed: ' + error.message);
            }
        }
    }

    async updateWalletBalance() {
        if (this.accountManagerContract && this.signer) {
            try {
                const address = await this.signer.getAddress();
                // Use getAccountInfo instead of getBalance
                const accountInfo = await this.accountManagerContract.getAccountInfo(address);
                // Account balance is the first return value
                const balanceInEth = window.ethers.utils.formatEther(accountInfo.balance);
                document.getElementById('walletBalance').textContent = balanceInEth;
            } catch (error) {
                console.error('Failed to update balance:', error);
            }
        }
    }


    async getPlayerBalance() {
        try {
            const address = await this.signer.getAddress();
            console.log('Getting balance for address:', address);
            
            // Get detailed account info
            const accountInfo = await this.accountManagerContract.getAccountInfo(address);
            console.log('Full account info:', accountInfo);
            
            // Convert balance to BigNumber and verify it's valid
            const balance = window.ethers.BigNumber.from(accountInfo.balance.toString());
            console.log('Parsed balance (Wei):', balance.toString());
            
            return balance;
        } catch (error) {
            console.error('Error getting player balance:', error);
            return window.ethers.BigNumber.from('0');
        }
    }

    async showResult(result) {
        const resultDisplay = document.getElementById('result');
        const isWin = this.checkWin(result);
        
        resultDisplay.textContent = `Result: ${result}`;
        resultDisplay.className = `result-display ${isWin ? 'win' : 'lose'}`;
        
        // Update balance immediately
        await this.updateWalletBalance();
        
        // Get current balance to show in win/lose message
        const currentBalance = await this.getPlayerBalance();
        const balanceInEth = ethers.utils.formatEther(currentBalance);
        
        // Show win/lose message with current balance
        alert(isWin ? 
            `Congratulations! You won! Your new balance is ${balanceInEth} ETH` : 
            `Sorry, you lost. Your new balance is ${balanceInEth} ETH`
        );
    }

    // Cập nhật hàm checkWin để kiểm tra thêm cược nhóm
    checkWin(result) {
        if (!this.currentBet) return false;

        if (this.currentBet.type === 'number') {
            return parseInt(result) === parseInt(this.currentBet.choice);
        }

        // Result = 0 luôn thua với cược chẵn/lẻ
        if (result === 0 && 
            (this.currentBet.type === 'even' || 
             this.currentBet.type === 'odd')) {
            return false;
        }

        // Check special bets
        switch (this.currentBet.type) {
            case 'even':
                return result % 2 === 0 && result !== 0;
            case 'odd':
                return result % 2 === 1;
            case '1st12':
                return result >= 1 && result <= 12;
            case '2nd12':
                return result >= 13 && result <= 24;
            case '3rd12':
                return result >= 25 && result <= 36;
            // ...existing cases...
        }
        return false;
    }

    isRedNumber(number) {
        const redNumbers = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
        return redNumbers.includes(number);
    }

    initializeUI() {
        this.createNumbersGrid();
        this.setupBettingListeners();
    }

    createNumbersGrid() {
        const mainGrid = document.querySelector('.main-grid');
        const numbers = Array.from({length: 36}, (_, i) => i + 1);
        
        numbers.forEach(num => {
            const cell = document.createElement('div');
            cell.className = `number-cell ${this.getNumberColor(num)}`;
            cell.textContent = num;
            cell.dataset.number = num;
            
            // Add tooltip
            cell.title = `Click to select/deselect ${num}`;
            
            cell.onclick = () => this.selectNumber(num);
            
            // Add hover effect handler
            cell.onmouseenter = () => this.handleCellHover(cell, true);
            cell.onmouseleave = () => this.handleCellHover(cell, false);
            
            mainGrid.appendChild(cell);
        });

        // Add zero with the same effects
        const zeroCell = document.createElement('div');
        zeroCell.className = 'number-cell green';
        zeroCell.textContent = '0';
        zeroCell.dataset.number = '0';
        zeroCell.title = 'Click to select/deselect 0';
        zeroCell.onclick = () => this.selectNumber(0);
        zeroCell.onmouseenter = () => this.handleCellHover(zeroCell, true);
        zeroCell.onmouseleave = () => this.handleCellHover(zeroCell, false);
        document.querySelector('.zero').appendChild(zeroCell);
    }

    selectNumber(num) {
        const selectedCell = document.querySelector(`[data-number="${num}"]`);
        
        // Bỏ chọn special bet nếu đang được chọn
        if (this.selectedBetType) {
            document.querySelectorAll('.btn-betting').forEach(btn => {
                btn.classList.remove('active');
            });
            this.selectedBetType = undefined;
        }

        // Nếu số đã được chọn, bỏ chọn nó
        if (this.selectedNumber === num) {
            selectedCell.classList.remove('selected');
            this.selectedNumber = undefined;
            console.log('Deselected number:', num);
            return;
        }

        // Remove selection from all cells
        document.querySelectorAll('.number-cell').forEach(cell => {
            cell.classList.remove('selected');
        });
        
        // Add selected class to clicked cell
        selectedCell.classList.add('selected');
        
        // Store the selected number
        this.selectedNumber = num;
        console.log('Selected number:', num);

        // Add sound effect
        this.playSelectSound();
    }

    // Thêm hiệu ứng âm thanh khi chọn số
    playSelectSound() {
        const audio = new Audio('assets/select.mp3'); // Tạo file âm thanh nhẹ
        audio.volume = 0.2; // Giảm volume
        audio.play().catch(() => {}); // Ignore errors if audio fails to play
    }

    // Thêm hiệu ứng hover
    handleCellHover(cell, isEntering) {
        if (!cell.classList.contains('selected')) {
            if (isEntering) {
                cell.style.transform = 'scale(1.1)';
            } else {
                cell.style.transform = 'scale(1)';
            }
        }
    }

    getNumberColor(num) {
        const redNumbers = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
        return redNumbers.includes(num) ? 'red' : 'black';
    }

    setupBettingListeners() {
        // Quick amount buttons
        document.querySelectorAll('.quick-amount-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                // Format số đúng cách ngay từ data attribute
                const amount = ethers.utils.formatUnits(
                    ethers.utils.parseEther(e.target.dataset.amount),
                    'ether'
                );
                document.getElementById('betAmount').value = amount;
            });
        });

        // Betting type buttons
        document.querySelectorAll('.btn-betting').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const betType = e.target.dataset.bet;
                
                // Nếu nút này đã active, chỉ bỏ chọn nó
                if (e.target.classList.contains('active')) {
                    e.target.classList.remove('active');
                    this.handleSpecialBet(betType); // Sẽ xử lý bỏ chọn
                    return;
                }

                // Bỏ chọn tất cả các nút khác
                document.querySelectorAll('.btn-betting').forEach(b => 
                    b.classList.remove('active')
                );
                
                // Thêm active cho nút được chọn
                e.target.classList.add('active');
                this.handleSpecialBet(betType);
            });
        });
    }

    handleSpecialBet(betType) {
        console.log(`Selected bet type: ${betType}`);

        // Kiểm tra nếu nút này đã được chọn thì bỏ chọn nó
        if (this.selectedBetType === betType) {
            // Bỏ chọn nút hiện tại
            document.querySelectorAll('.btn-betting').forEach(btn => {
                if (btn.dataset.bet === betType) {
                    btn.classList.remove('active');
                }
            });
            this.selectedBetType = undefined;
            console.log('Deselected bet type:', betType);
            return;
        }

        // Bỏ chọn số đơn nếu đang được chọn
        if (this.selectedNumber !== undefined) {
            const previousSelectedCell = document.querySelector(`[data-number="${this.selectedNumber}"]`);
            if (previousSelectedCell) {
                previousSelectedCell.classList.remove('selected');
            }
            this.selectedNumber = undefined;
        }

        // Store the selected bet type
        this.selectedBetType = betType;

        // Log trạng thái mới
        console.log('Current state:', {
            selectedNumber: this.selectedNumber,
            selectedBetType: this.selectedBetType
        });
    }

    setupBackgroundMusic() {
        // Add music control button to the header
        const navbar = document.querySelector('.navbar-brand');
        const musicBtn = document.createElement('button');
        musicBtn.className = 'btn btn-outline-light btn-sm ms-3';
        musicBtn.innerHTML = '<i class="fas fa-music"></i>';
        musicBtn.title = 'Toggle Background Music';
        
        // Toggle music when clicked
        musicBtn.addEventListener('click', () => {
            if (this.backgroundMusic.paused) {
                this.backgroundMusic.play();
                musicBtn.classList.add('active');
            } else {
                this.backgroundMusic.pause();
                musicBtn.classList.remove('active');
            }
        });
        
        navbar.appendChild(musicBtn);

        // Start playing when user interacts with the page
        const startMusic = () => {
            this.backgroundMusic.currentTime = 15; // Ensure 15s start point even after user interaction
            this.backgroundMusic.play().catch(() => {});
            document.removeEventListener('click', startMusic);
        };
        document.addEventListener('click', startMusic);

        // Add timeupdate listener to maintain loop from 15s
        this.backgroundMusic.addEventListener('timeupdate', () => {
            // If the music reaches the end, reset to 15s
            if (this.backgroundMusic.currentTime >= this.backgroundMusic.duration - 0.1) {
                this.backgroundMusic.currentTime = 15;
            }
        });
    }

    // Add cleanup method for when component is destroyed
    cleanup() {
        if (this.backgroundMusic) {
            this.backgroundMusic.pause();
            this.backgroundMusic.src = '';
        }
    }
}

// Initialize game when page loads
window.addEventListener('DOMContentLoaded', () => {
    const game = new RouletteGame();
    game.initializeUI();
    
    // Clean up when page is unloaded
    window.addEventListener('beforeunload', () => {
        game.cleanup();
    });
});