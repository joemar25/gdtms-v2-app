/**
 * User type definitions
 */

// when logged in:
// {
//     "success": true,
//     "message": "Login successful",
//     "data": {
//         "token": "143|6C6jRg5k7zFKMhTRexy6M5LX2Ryyeugs2l0mEidcf1bd6fcd",
//         "session_revoked": true,
//         "session_revoked_message": "Your previous session on another device has been logged out. Only one active session is allowed at a time.",
//         "user": {
//             "id": 401,
//             "name": "achilles543",
//             "first_name": "ACHILLES",
//             "middle_name": "ACOJIDO",
//             "last_name": "CARACUEL",
//             "email": null,
//             "phone_number": "REDACTED_TEST_NUMBER"
//         },
//         "courier": {
//             "id": 543,
//             "courier_code": "CC00543",
//             "courier_type": "1",
//             "branch_id": 1
//         }
//     }
// }

export interface User {
    id: number;
    name: string;
    email?: string | null;
    phone?: string;
    avatar?: string;
    profile_url?: string;
}

export interface Auth {
    user?: User | null;
}
