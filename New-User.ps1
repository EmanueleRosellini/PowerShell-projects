function New-User {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $false)]
        [PSCustomObject]$UserInput
    )

    begin {
        Import-Module ActiveDirectory -ErrorAction Stop
        $ErrorLogPath = "error_log.txt"
        if (Test-Path $ErrorLogPath) { Remove-Item $ErrorLogPath }

        # Starting UID numbers (should be persisted in production, e.g. from a file/db)
        $uidCounters = @{
            'employee' = 1
            'external' = 1
            'trainee'  = 1
        }

        # Helper: Get next UID
        function Get-NextUID([string]$role) {
            $prefix = switch ($role) {
                'employee' { 'U' }
                'external' { 'F' }
                'trainee' { 'S' }
                default { throw "Invalid role for UID generation" }
            }
            $uidNum = $uidCounters[$role]
            $uidCounters[$role]++
            return "$prefix{0:D5}" -f $uidNum
        }

        # Helper: Email validation
        function IsValidEmail($email) {
            return $email -match '^[\w\.-]+@[\w\.-]+\.\w{2,}$'
        }

        # Helper: Generate random password
        function New-RandomPassword {
            Add-Type -AssemblyName System.Web
            return [System.Web.Security.Membership]::GeneratePassword(12, 2)
        }

        # Helper: Convert to FileTime
        function ConvertTo-FileTime($dt) {
            $epoch = [datetime]"1601-01-01T00:00:00Z"
            $utcDt = $dt.ToUniversalTime()
            $diff = $utcDt - $epoch
            return [int64]($diff.TotalSeconds * 10000000)
        }
    }

    process {
        try {
            # Read data
            $firstName = $UserInput.Name
            $lastName = $UserInput.Surname
            $role = $UserInput.Role.ToLower()

            if ($role -notin @('employee', 'external', 'trainee')) {
                throw "Invalid role: $role"
            }

            # Validate and parse birthday
            if (-not [datetime]::TryParseExact($UserInput.Birthday, 'yyyy-MM-dd', $null, [System.Globalization.DateTimeStyles]::None, [ref]$null)) {
                throw "Invalid birthday format (expected yyyy-MM-dd): $($UserInput.Birthday)"
            }
            $birthday = [datetime]::ParseExact($UserInput.Birthday, 'yyyy-MM-dd', $null)

            # UID generation
            $uid = Get-NextUID $role
            $samAccountName = $uid
            $userPrincipalName = "$uid@vontobel.com"  # Update domain as needed
            $displayName = "$firstName $lastName"
            $ou = "OU=Users,DC=vontobel,DC=com"       # OU based on role can be implemented here

            # Expiration logic
            $expireDate = switch ($role) {
                'employee' { [datetime]"9999-12-12" }
                'external' { (Get-Date).AddMonths(6) }
                'trainee' { (Get-Date).AddMonths(3) }
            }
            $accountExpiresValue = ConvertTo-FileTime $expireDate

            # Password generation
            $plainPassword = New-RandomPassword
            $securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force

            # Construct email
            $email = "$uid@vontobel.com"  # Auto-generate based on UID

            $userParams = @{
                Name                  = $displayName
                GivenName             = $firstName
                Surname               = $lastName
                SamAccountName        = $samAccountName
                UserPrincipalName     = $userPrincipalName
                Path                  = $ou
                AccountPassword       = $securePassword
                Enabled               = $true
                EmailAddress          = $email
                Description           = "Birthday: $($birthday.ToString('yyyy-MM-dd'))"
                AccountExpirationDate = $expireDate
            }

            # Create AD User
            New-ADUser @userParams
            Set-ADUser -Identity $samAccountName -Replace @{accountExpires = $accountExpiresValue }
            Write-Host "User $displayName ($uid) created." -ForegroundColor Green

            # Assign groups
            $groupsByRole = @{
                'employee' = @('EmployeesGroup', 'EmailEnabledUsers')
                'external' = @('ExternalContractors')
                'trainee'  = @('TraineesGroup', 'LimitedAccessUsers')
            }

            foreach ($group in $groupsByRole[$role]) {
                try {
                    Add-ADGroupMember -Identity $group -Members $samAccountName
                    Write-Host "Added $samAccountName to group $group." -ForegroundColor Cyan
                }
                catch {
                    $errorMsg = "Failed to add $samAccountName to group $group: $_"
                    Add-Content -Path $ErrorLogPath -Value $errorMsg
                    Write-Host $errorMsg -ForegroundColor Yellow
                }
            }

            # Email HTML body
			
            $htmlBody = @"
			<html>
			<head>
			  <style>
				body { font-family: Arial, sans-serif; color: #333; }
				.header { font-size: 18px; font-weight: bold; margin-bottom: 15px; }
				.section { margin-bottom: 10px; }
				.code { font-family: Consolas, monospace; color: #2e6da4; }
				.footer { font-size: 12px; color: #999; margin-top: 20px; }
			  </style>
			</head>
			<body>
			  <div class="header">Your IAM Account Has Been Created</div>
			  <div class="section">Hello <strong>$firstName</strong>,</div>
			  <div class="section">Your new user account has been successfully provisioned. Below are your login details:</div>

			  <div class="section">
				<strong>Username:</strong> <span class="code">$samAccountName</span><br/>
				<strong>Initial Password:</strong> <span class="code">$plainPassword</span>
			  </div>

			  <div class="section">Please log in and change your password at first login.</div>

			  <div class="footer">Sent by IT Automation System – Do not reply to this email.</div>
			</body>
			</html>
"@
            
            # SMTP settings
            $smtpSettings = @{
                SmtpServer  = 'smtp.vontobel.com'   # Change!
                Port        = 587
                UseSsl      = $true
                Credential  = (Get-Credential -Message "Enter SMTP credentials for email sending")
                From        = 'no-reply@vontobel.com'
                To          = $email
                Subject     = "Your IAM Account Credentials"
                Body        = $htmlBody
                BodyAsHtml  = $true
            }

            Send-MailMessage @smtpSettings

            Write-Host "Password sent to $email." -ForegroundColor Green
        } catch {
            $errorText = "Error provisioning user [$($UserInput.Name) $($UserInput.Surname)]: $_"
            Add-Content -Path $ErrorLogPath -Value $errorText
            Write-Host $errorText -ForegroundColor Red
        }
    }

    end {
        Write-Host "Provisioning process completed."
        if (Test-Path $ErrorLogPath) {
            Write-Host "Some errors occurred. Check error_log.txt for details." -ForegroundColor Yellow
        }
    }
}
