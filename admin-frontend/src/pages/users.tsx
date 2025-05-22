import React, { useState, useEffect } from 'react';
import { Box, Button, Heading, Table, Thead, Tbody, Tr, Th, Td, HStack, 
  Badge, IconButton, useDisclosure, Modal, ModalOverlay, ModalContent, 
  ModalHeader, ModalBody, ModalFooter, ModalCloseButton, FormControl, 
  FormLabel, Input, Select, useToast, Switch, Text, AlertDialog, 
  AlertDialogBody, AlertDialogFooter, AlertDialogHeader, AlertDialogContent, 
  AlertDialogOverlay } from '@chakra-ui/react';
import { FiEdit, FiTrash2, FiUserPlus } from 'react-icons/fi';
import Layout from '@/components/Layout';
import axios from 'axios';
import { useRouter } from 'next/router';

// Define User interface
interface User {
  id: string;
  username: string;
  email: string;
  role: string;
  isActive: boolean;
  lastLogin?: string;
  createdAt?: string;
  // Add any other properties from your user object
}

export default function Users() {
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const { isOpen: isModalOpen, onOpen: onModalOpen, onClose: onModalClose } = useDisclosure();
  const { isOpen: isAlertOpen, onOpen: onAlertOpen, onClose: onAlertClose } = useDisclosure();
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
    role: 'viewer',
    isActive: true
  });
  const [isEdit, setIsEdit] = useState(false);
  const toast = useToast();
  const router = useRouter();
  const cancelRef = React.useRef<HTMLButtonElement>(null);

  useEffect(() => {
    // Check if user is authenticated
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/login');
      return;
    }

    fetchUsers();
  }, [router]);

  const fetchUsers = async () => {
    setIsLoading(true);
    try {
      const response = await axios.get(`${process.env.API_URL}/users`, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`
        }
      });
      setUsers(response.data);
    } catch (error) {
      console.error('Error fetching users:', error);
      toast({
        title: 'Error',
        description: 'Failed to fetch users',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value, checked } = e.target as HTMLInputElement;
    setFormData({
      ...formData,
      [name]: name === 'isActive' ? checked : value
    });
  };

  const openAddModal = () => {
    setIsEdit(false);
    setFormData({
      username: '',
      email: '',
      password: '',
      role: 'viewer',
      isActive: true
    });
    onModalOpen();
  };

  const openEditModal = (user: User) => {
    setIsEdit(true);
    setSelectedUser(user);
    setFormData({
      username: user.username,
      email: user.email,
      password: '',
      role: user.role,
      isActive: user.isActive
    });
    onModalOpen();
  };

  const openDeleteDialog = (user: User) => {
    setSelectedUser(user);
    onAlertOpen();
  };

  const handleSubmit = async () => {
    try {
      if (isEdit) {
        // Update existing user
        if (!selectedUser) {
          throw new Error('No user selected for update');
        }
        await axios.put(
          `${process.env.API_URL}/users/${selectedUser.id}`,
          formData,
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`
            }
          }
        );
        toast({
          title: 'Success',
          description: 'User updated successfully',
          status: 'success',
          duration: 3000,
          isClosable: true,
        });
      } else {
        // Create new user
        await axios.post(
          `${process.env.API_URL}/users`,
          formData,
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`
            }
          }
        );
        toast({
          title: 'Success',
          description: 'User created successfully',
          status: 'success',
          duration: 3000,
          isClosable: true,
        });
      }
      onModalClose();
      fetchUsers();
    } catch (error) {
      console.error('Error submitting user:', error);
      const axiosError = error as any; // Type assertion for axios error
      toast({
        title: 'Error',
        description: axiosError.response?.data?.message || 'Failed to save user',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  };

  const handleDelete = async () => {
    try {
      if (!selectedUser) {
        throw new Error('No user selected for deletion');
      }
      await axios.delete(
        `${process.env.API_URL}/users/${selectedUser.id}`,
        {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`
          }
        }
      );
      toast({
        title: 'Success',
        description: 'User deleted successfully',
        status: 'success',
        duration: 3000,
        isClosable: true,
      });
      onAlertClose();
      fetchUsers();
    } catch (error) {
      console.error('Error deleting user:', error);
      const axiosError = error as any; // Type assertion for axios error
      toast({
        title: 'Error',
        description: axiosError.response?.data?.message || 'Failed to delete user',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  };

  return (
    <Layout>
      <Box p={6}>
        <HStack justifyContent="space-between" mb={6}>
          <Heading>User Management</Heading>
          <Button 
            leftIcon={<FiUserPlus />} 
            colorScheme="blue" 
            onClick={openAddModal}
          >
            Add User
          </Button>
        </HStack>

        <Box bg="white" borderRadius="lg" boxShadow="md" p={4} overflowX="auto">
          <Table variant="simple">
            <Thead>
              <Tr>
                <Th>Username</Th>
                <Th>Email</Th>
                <Th>Role</Th>
                <Th>Status</Th>
                <Th>Last Login</Th>
                <Th>Actions</Th>
              </Tr>
            </Thead>
            <Tbody>
              {isLoading ? (
                <Tr>
                  <Td colSpan={6} textAlign="center">Loading...</Td>
                </Tr>
              ) : users.length === 0 ? (
                <Tr>
                  <Td colSpan={6} textAlign="center">No users found</Td>
                </Tr>
              ) : (
                users.map((user) => (
                  <Tr key={user.id}>
                    <Td>{user.username}</Td>
                    <Td>{user.email}</Td>
                    <Td>
                      <Badge colorScheme={
                        user.role === 'admin' ? 'purple' : 
                        user.role === 'manager' ? 'blue' : 'gray'
                      }>
                        {user.role}
                      </Badge>
                    </Td>
                    <Td>
                      <Badge colorScheme={user.isActive ? 'green' : 'red'}>
                        {user.isActive ? 'Active' : 'Inactive'}
                      </Badge>
                    </Td>
                    <Td>{user.lastLogin ? new Date(user.lastLogin).toLocaleString() : 'Never'}</Td>
                    <Td>
                      <HStack spacing={2}>
                        <IconButton
                          aria-label="Edit user"
                          icon={<FiEdit />}
                          size="sm"
                          onClick={() => openEditModal(user)}
                        />
                        <IconButton
                          aria-label="Delete user"
                          icon={<FiTrash2 />}
                          size="sm"
                          colorScheme="red"
                          onClick={() => openDeleteDialog(user)}
                        />
                      </HStack>
                    </Td>
                  </Tr>
                ))
              )}
            </Tbody>
          </Table>
        </Box>
      </Box>

      {/* Add/Edit User Modal */}
      <Modal isOpen={isModalOpen} onClose={onModalClose}>
        <ModalOverlay />
        <ModalContent>
          <ModalHeader>{isEdit ? 'Edit User' : 'Add New User'}</ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            <FormControl mb={4}>
              <FormLabel>Username</FormLabel>
              <Input
                name="username"
                value={formData.username}
                onChange={handleInputChange}
              />
            </FormControl>

            <FormControl mb={4}>
              <FormLabel>Email</FormLabel>
              <Input
                name="email"
                type="email"
                value={formData.email}
                onChange={handleInputChange}
              />
            </FormControl>

            <FormControl mb={4}>
              <FormLabel>Password {isEdit && '(leave blank to keep current)'}</FormLabel>
              <Input
                name="password"
                type="password"
                value={formData.password}
                onChange={handleInputChange}
              />
            </FormControl>

            <FormControl mb={4}>
              <FormLabel>Role</FormLabel>
              <Select
                name="role"
                value={formData.role}
                onChange={handleInputChange}
              >
                <option value="viewer">Viewer</option>
                <option value="manager">Manager</option>
                <option value="admin">Admin</option>
              </Select>
            </FormControl>

            <FormControl display="flex" alignItems="center" mb={4}>
              <FormLabel mb="0">Active</FormLabel>
              <Switch
                name="isActive"
                isChecked={formData.isActive}
                onChange={handleInputChange}
              />
            </FormControl>
          </ModalBody>

          <ModalFooter>
            <Button variant="ghost" mr={3} onClick={onModalClose}>
              Cancel
            </Button>
            <Button colorScheme="blue" onClick={handleSubmit}>
              {isEdit ? 'Update' : 'Create'}
            </Button>
          </ModalFooter>
        </ModalContent>
      </Modal>

      {/* Delete Confirmation Dialog */}
      <AlertDialog
        isOpen={isAlertOpen}
        leastDestructiveRef={cancelRef}
        onClose={onAlertClose}
      >
        <AlertDialogOverlay>
          <AlertDialogContent>
            <AlertDialogHeader fontSize="lg" fontWeight="bold">
              Delete User
            </AlertDialogHeader>

            <AlertDialogBody>
              Are you sure you want to delete {selectedUser?.username}? This action cannot be undone.
            </AlertDialogBody>

            <AlertDialogFooter>
              <Button ref={cancelRef} onClick={onAlertClose}>
                Cancel
              </Button>
              <Button colorScheme="red" onClick={handleDelete} ml={3}>
                Delete
              </Button>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialogOverlay>
      </AlertDialog>
    </Layout>
  );
}
