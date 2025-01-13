 import { useDynamicContext } from "@dynamic-labs/sdk-react-core";

const { user } = useDynamicContext();

return (
  <div className="user-details">
    {user?.firstName && <p>First name: {user.firstName} </p>}
    {user?.email && <p>E-Mail: {user.email} </p>}
    {user?.alias && <p>Alias: {user.alias} </p>}
    {user?.lastName && <p>Last name: {user.lastName} </p>}
    {user?.jobTitle && <p>Job: {user.jobTitle} </p>}
    {user?.phoneNumber && <p>Phone: {user.phoneNumber} </p>}
    {user?.tShirtSize && <p>Tshirt size: {user.tShirtSize} </p>}
    {user?.team && <p>Team: {user.team} </p>}
    {user?.country && <p>Country: {user.country} </p>}
    {user?.username && <p>Username: {user.username} </p>}
  </div>
);
