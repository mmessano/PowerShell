    #####################################################################
    # New-CodeSigningCertificate.ps1
    # Version 1.0
    #
    # Creates new self-signed code signing certificate and installs it to
    # current user's personal store. Supports Windows XP and higher.
    #
    # Initially script was developed for Quest PowerGUI ScriptEditor add-on.
    #
    # Vadims Podans (c) 2011
    # http://en-us.sysadmins.lv/
    #####################################################################
    #requires -Version 2.0
     
    function New-CodeSigningCertificate {
    [CmdletBinding()]
            param(
                    [Security.Cryptography.X509Certificates.X500DistinguishedName]$Subject = "CN=PowerGUI User",
                    [ValidateSet(1024,2048)]
                    [int]$KeyLength = 2048,
                    [DateTime]$ValidFrom = [datetime]::Now,
                    [DateTime]$ValidTo = [datetime]::Now.AddYears(1)
            )
    $signature = @"
    [DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern bool CryptAcquireContext(
      ref IntPtr phProv,
      string pszContainer,
      string pszProvider,
      uint dwProvType,
      Int64 dwFlags
    );
    [DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern bool CryptReleaseContext(
            IntPtr phProv,
            int flags
    );
    [DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern bool CryptGenKey(
            IntPtr phProv,
            int Algid,
            int dwFlags,
            ref IntPtr phKey
    );
    [DllImport("Crypt32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern bool CryptExportPublicKeyInfo(
            IntPtr phProv,
            int dwKeySpec,
            int dwCertEncodingType,
            IntPtr pbInfo,
            ref int pcbInfo
    );
    [DllImport("Crypt32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern bool CryptHashPublicKeyInfo(
            IntPtr phProv,
            int Algid,
            int dwFlags,
            int dwCertEncodingType,
            IntPtr pInfo,
            IntPtr pbComputedHash,
            ref int pcbComputedHash
    );
    [DllImport("Crypt32.dll", SetLastError=true)]
    public static extern bool CryptEncodeObject(
            int dwCertEncodingType,
            [MarshalAs(UnmanagedType.LPStr)]string lpszStructType,
            ref CRYPTOAPI_BLOB pvStructInfo,
            byte[] pbEncoded,
            ref int pcbEncoded
    );
     
    [DllImport("Crypt32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern IntPtr CertCreateSelfSignCertificate(
            IntPtr phProv,
            CRYPTOAPI_BLOB pSubjectIssuerBlob,
            int flags,
            CRYPT_KEY_PROV_INFO pKeyProvInfo,
            IntPtr pSignatureAlgorithm,
            SystemTime pStartTime,
            SystemTime pEndTime,
            CERT_EXTENSIONS pExtensions
    );
    [DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern bool CryptDestroyKey(
            IntPtr cryptKeyHandle
    );
    [DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern bool FileTimeToSystemTime(
            [In] ref long fileTime,
            out SystemTime SystemTime
    );
     
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct CRYPT_KEY_PROV_INFO {
            public string pwszContainerName;
            public string pwszProvName;
            public int dwProvType;
            public int dwFlags;
            public int cProvParam;
            public IntPtr rgProvParam;
            public int dwKeySpec;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct CERT_EXTENSIONS {
            public int cExtension;
            public IntPtr rgExtension;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct CERT_EXTENSION {
            [MarshalAs(UnmanagedType.LPStr)]public String pszObjId;
            public Boolean fCritical;
            public CRYPTOAPI_BLOB Value;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct CERT_BASIC_CONSTRAINTS2_INFO {
            public Boolean fCA;
            public Boolean fPathLenConstraint;
            public int dwPathLenConstraint;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct CRYPTOAPI_BLOB {
            public int cbData;
            public IntPtr pbData;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct CRYPT_BIT_BLOB {
            public uint cbData;
            public IntPtr pbData;
            public uint cUnusedBits;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct CERT_PUBLIC_KEY_INFO {
            public CRYPT_ALGORITHM_IDENTIFIER Algorithm;
            public CRYPT_BIT_BLOB PublicKey;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct CRYPT_ALGORITHM_IDENTIFIER {
            [MarshalAs(UnmanagedType.LPStr)]public String pszObjId;
            public CRYPTOAPI_BLOB Parameters;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct SystemTime {
            public short Year;
            public short Month;
            public short DayOfWeek;
            public short Day;
            public short Hour;
            public short Minute;
            public short Second;
            public short Milliseconds;
    }
    "@
            Add-Type -MemberDefinition $signature -Namespace Quest -Name PowerGUI
            $pszContainer = [Guid]::NewGuid().ToString()
            [IntPtr]$phProv = [IntPtr]::Zero
            $Provider = "Microsoft Base Cryptographic Provider v1.0"
            $Result = [Quest.PowerGUI]::CryptAcquireContext([ref]$phProv,$pszContainer,$Provider,0x1,0x8)
            if (!$Result) {Write-Warning "Unable to create provider context!"; return}
            [IntPtr]$phKey = [IntPtr]::Zero
            if ($KeyLength -eq 2048) {
                    $Result = [Quest.PowerGUI]::CryptGenKey($phProv,2,0x08000001,[ref]$phKey)
            } else {
                    $Result = [Quest.PowerGUI]::CryptGenKey($phProv,2,0x04000001,[ref]$phKey)
            }
            if (!$Result) {Write-Warning "Unable to create key context!"; return}
            $dataHandle = [Runtime.InteropServices.GCHandle]::Alloc($Subject.RawData,"pinned")
            $ptrName = New-Object Quest.PowerGUI+CRYPTOAPI_BLOB -Property @{
                    cbData = $Subject.RawData.Count;
                    pbData = $dataHandle.AddrOfPinnedObject()
            }
            $PrivateKey = New-Object Quest.PowerGUI+CRYPT_KEY_PROV_INFO -Property @{
                    pwszContainerName = $pszContainer;
                    pwszProvName = $Provider;
                    dwProvType = 1;
                    dwKeySpec = 2
            }
            $Extensions = New-Object Security.Cryptography.X509Certificates.X509ExtensionCollection
            # add Basic Constraints extension
            [void]$Extensions.Add((New-Object Security.Cryptography.X509Certificates.X509BasicConstraintsExtension $false,$false,0,$false))
            # add Code Signing EKU
            $OIDs = New-Object Security.Cryptography.OidCollection
            [void]$OIDs.Add("code signing")
            [void]$Extensions.Add((New-Object Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension -ArgumentList $OIDs, $false))
            # add SKI extension
            $pcbInfo = 0
            if (([Quest.PowerGUI]::CryptExportPublicKeyInfo($phProv,2,1,[IntPtr]::Zero,[ref]$pcbInfo))) {
                    $pbInfo = [Runtime.InteropServices.Marshal]::AllocHGlobal($pcbInfo)
                    $Return = [Quest.PowerGUI]::CryptExportPublicKeyInfo($phProv,2,1,$pbInfo,[ref]$pcbInfo)
                    $pcbComputedHash = 0
                    if (([Quest.PowerGUI]::CryptHashPublicKeyInfo([IntPtr]::Zero,0x00008004,0,1,$pbInfo,[IntPtr]::Zero,[ref]$pcbComputedHash))) {
                            $pbComputedHash = [Runtime.InteropServices.Marshal]::AllocHGlobal($pcbComputedHash)
                            [void][Quest.PowerGUI]::CryptHashPublicKeyInfo([IntPtr]::Zero,0x00008004,0,1,$pbInfo,$pbComputedHash,[ref]$pcbComputedHash)
                            $pcbEncoded = 0
                            $uSKI = New-Object Quest.PowerGUI+CRYPTOAPI_BLOB -Property @{
                                    cbData = $pcbComputedHash;
                                    pbData = $pbComputedHash
                            }
                            $pcbEncoded = 0
                            if (([Quest.PowerGUI]::CryptEncodeObject(1,"2.5.29.14",[ref]$uSKI,$null,[ref]$pcbEncoded))) {
                                    $pbEncoded = New-Object byte[] -ArgumentList $pcbEncoded
                                    $Return = [Quest.PowerGUI]::CryptEncodeObject(1,"2.5.29.14",[ref]$uSKI,$pbEncoded,[ref]$pcbEncoded)
                                    $AsnEncodedData = New-Object Security.Cryptography.AsnEncodedData -ArgumentList "2.5.29.14", $pbEncoded
                                    [void]$Extensions.Add((New-Object Security.Cryptography.X509Certificates.X509SubjectKeyIdentifierExtension -ArgumentList $AsnEncodedData, $false))
                            }
                    }
            }
            # add KeyUsages extension
            [void]$Extensions.Add((New-Object Security.Cryptography.X509Certificates.X509KeyUsageExtension -ArgumentList "DigitalSignature", $true))
            # transform managed extensions to unmanaged structures
            $uExtensionCollection = @()
            foreach ($mExt in $Extensions) {
                    $uExtension = New-Object Quest.PowerGUI+CERT_EXTENSION
                    $uExtension.pszObjId = $mExt.Oid.Value
                    $uExtension.fCritical = $mExt.Critical
                    $value = New-Object Quest.PowerGUI+CRYPTOAPI_BLOB
                    $value.cbData = $mExt.RawData.Length
                    $value.pbData = [Runtime.InteropServices.Marshal]::AllocHGlobal($value.cbData)
                    [Runtime.InteropServices.Marshal]::Copy($mExt.RawData,0,$Value.pbData,$Value.cbData)
                    $uExtension.Value = $value
                    $uExtensionCollection += $uExtension
            }
            $uExtensions = New-Object Quest.PowerGUI+CERT_EXTENSIONS
            $ExtensionSize = [Runtime.InteropServices.Marshal]::SizeOf([Quest.PowerGUI+CERT_EXTENSION]) * $Extensions.Count
            $uExtensions.cExtension = $Extensions.Count
            $uExtensions.rgExtension = [Runtime.InteropServices.Marshal]::AllocHGlobal($ExtensionSize)
            for ($n = 0; $n -lt $Extensions.Count; ++$n) {
                    $offset = $n * [Runtime.InteropServices.Marshal]::SizeOf([Quest.PowerGUI+CERT_EXTENSION])
                    $next = $offset + $uExtensions.rgExtension.ToInt64()
                    [IntPtr]$NextAddress = New-Object IntPtr $next
                    [Runtime.InteropServices.Marshal]::StructureToPtr($uExtensionCollection[$n],$NextAddress,$false)
            }
            $pStartTime = New-Object Quest.PowerGUI+SystemTime
            [void][Quest.PowerGUI]::FileTimeToSystemTime([ref]$ValidFrom.ToFileTime(),[ref]$pStartTime)
            $pEndTime = New-Object Quest.PowerGUI+SystemTime
            [void][Quest.PowerGUI]::FileTimeToSystemTime([ref]$ValidTo.ToFileTime(),[ref]$pEndTime)
            $pvContext = [Quest.PowerGUI]::CertCreateSelfSignCertificate($phProv,$ptrName,0,$PrivateKey,[IntPtr]::Zero,$pStartTime,$pEndTime,$uExtensions)
            if (!$pvContext.Equals([IntPtr]::Zero)) {
                    New-Object Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $pvContext
            }
            # release memory
            foreach ($uExt in $uExtensionCollection) {
                    [void][Runtime.InteropServices.Marshal]::FreeHGlobal($uExt.Value.pbData)
            }
            [void][Runtime.InteropServices.Marshal]::FreeHGlobal($uExtensions.rgExtension)
            [void][Runtime.InteropServices.Marshal]::FreeHGlobal($pbInfo)
            [void][Runtime.InteropServices.Marshal]::FreeHGlobal($pbComputedHash)
            [void]$dataHandle.Free()
            [void][Quest.PowerGUI]::CryptDestroyKey($phKey)
            [void][Quest.PowerGUI]::CryptReleaseContext($phProv,0)
    }
